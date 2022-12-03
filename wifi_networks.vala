/* Search for wireless networks that are known to the computer the program is
 * running on, connect to each, and output the default gateway for each network.
 * 
 * Collected fields for each network:
 * - ssid
 * - auth-alg
 * - key-mgmt
 * - psk
 * 
 * Exit code (0: success, 1:failure)
 */

using GLib;

public class WifiNetworkScanner : Object {
	public GLib.List<HashTable> network_list;
	public string wifi_interface = "";
	public GLib.List<string> ssid_list = new GLib.List<string>();

	public WifiNetworkScanner () {
		this.network_list = new GLib.List<HashTable>();
	}

	/* Check wireless network configuration files, gather security parameters, and
	 * collect them in global list.
	 */
	public int check_network_manager_config_files () {
		var file_list = new GLib.List<string>();
		string network_manager_config_location = "/etc/NetworkManager/system-connections";

		try {
			/* List all NetworkManager config files */
			string standard_output, standard_error;
			int exit_status;
			Process.spawn_command_line_sync (
				"ls %s".printf(network_manager_config_location),
				out standard_output,
				out standard_error,
				out exit_status
			);

			if (exit_status == 512) {
				stderr.printf("Error: Not enough privileges, please run as root");
				return 1;
			} else {
				/* Clean up for empty elements */
				foreach (string filename in standard_output.split ("\n")) {
					if (filename != "") {
						file_list.append(filename);
					}
				}
			}
		} catch (SpawnError e) {
			stderr.printf("%s\n", e.message);
		}

		/* Read each NetworkManager file */
		foreach (string filename in file_list) {
			try {
				string file_contents;
				FileUtils.get_contents (
					"%s/%s".printf(network_manager_config_location, filename),
					out file_contents
				);

				/* filter by wireless networks*/
				if ("type=wifi" in file_contents) {

					/* Filter by the necessary fields:
					 * - ssid
					 * - auth-alg
					 * - key-mgmt
					 * - psk
					 */
					foreach (string net_param in file_contents.split ("\n")) {
						if (Regex.match_simple (
							"(ssid|auth-alg|key-mgmt|psk)",
							net_param
						)) {
							string[] new_net = net_param.split("=");
							var hash = new HashTable<string, string> (str_hash, str_equal);
							hash.insert(new_net[0], new_net[1]);
							network_list.append (hash);
						}
					}
				}
			} catch (FileError e) {
				stderr.printf ("%s\n", e.message);
			}
		}

		return 0;
	}

	/* Run an active scan for available wireless networks, using NetworkManager.
	 * Add findings to global network_list.
	 */
	public int network_manager_active_scan () {

		try {
			stdout.printf ("Scanning for wireless network interfaces...");
			/* Find wireless interfaces with `iw` */
			string standard_output, standard_error;
			int exit_status;
			Process.spawn_command_line_sync (
				"iw dev",
				out standard_output,
				out standard_error,
				out exit_status
			);

			foreach (string interface in standard_output.split ("\n")) {
				if ("Interface" in interface) {
					wifi_interface = interface.split (" ")[1];
				}
			}
		} catch (SpawnError e) {
			stderr.printf("%s\n", e.message);
			return 1;
		}

		/* In case no wifi interface is found (e.g. desktop) */
		if (wifi_interface == "") {
			stderr.printf("Error: No wireless network interfaces were found.");
			return 1;
		} else {
			stdout.printf("Found.\n");
		}

		stdout.printf ("Scanning for available access points...");

		try {
			string standard_output, standard_error;
			int exit_status;
			Process.spawn_command_line_sync (
				"iw dev " + wifi_interface + " scan",
				out standard_output,
				out standard_error,
				out exit_status
			);

			stdout.printf ("Found.\n");

			foreach (string iw_param in standard_output.split ("\n")) {
				if ("SSID" in iw_param) {
					ssid_list.append (iw_param.split(": ")[1]);
				}
			}
		} catch (SpawnError e) {
			stderr.printf("%s\n", e.message);
			return 1;
		}

		return 0;
	}
}

int main () {
	WifiNetworkScanner scanner = new WifiNetworkScanner ();

	/* Search NetworkManager files, filter by wireless networks. */
	if (scanner.check_network_manager_config_files () == 1) {
		return 1;
	}/* else {
		foreach (HashTable<string,string> network in scanner.network_list) {
			foreach (string key in network.get_keys()) {
				stdout.printf ("%s => %s \n", key, network.lookup(key));
			}
		}
	}*/

	/* Perform an active scan for available wireless networks*/
	if (scanner.network_manager_active_scan () != 0) {
		stderr.printf ("Error: No wireless networks are available.");
	} else {
		stdout.printf ("Found wireless network SSIDs:\n");
		foreach (string ssid in scanner.ssid_list) {
			stdout.printf("\t%s\n", ssid);
		}
	}

	/* Match available and known networks, connect to them. */
	foreach (string ssid in scanner.ssid_list) {
		foreach (HashTable<string,string> known_network in scanner.network_list) {
			if (ssid == known_network.lookup("ssid")) {
				//stdout.printf ("known SSID: %s\n", ssid);
				string standard_output, standard_error;
				int exit_status;
				try {
					Process.spawn_command_line_sync (
						"nmcli connection up " + ssid,
						out standard_output,
						out standard_error,
						out exit_status
					);
				} catch (SpawnError e) {
					stderr.printf("%s\n", e.message);
					return 1;
				}

				/* Once connected, locate the default gateway */
				try {
					Process.spawn_command_line_sync (
						"ip route",
						out standard_output,
						out standard_error,
						out exit_status
					);

					foreach (string route in standard_output.split ("\n")) {
						if ("default" in route) {
							string gateway = route.split(" ")[2];
							stdout.printf("SSID: %s - Default Gateway: %s", ssid, gateway);
						}
					}

				} catch (SpawnError e) {
					stderr.printf("%s\n", e.message);
					return 1;
				}
				
			}
		}
	}

	return 0;
}
