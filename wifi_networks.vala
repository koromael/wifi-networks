/* Search for wireless networks that are known to the computer the program is
 * running on, connect to each, and output the default gateway for each network.
 * 
 * Exit code (0: success, 1:failure)
 */

using GLib;

public class WifiNetworkScanner : Object {
	public GLib.List<HashTable> network_list;

	public WifiNetworkScanner () {
		this.network_list = new GLib.List<HashTable>();
	}

	/* Check wireless network configuration files */
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
				stderr.printf("ERROR: not enough privileges, please run as root");
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

					/* Filter by the necessary fields */
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
}

int main () {
	WifiNetworkScanner scanner = new WifiNetworkScanner ();

	if (scanner.check_network_manager_config_files () == 1) {
		return 1;
	} else {
		foreach (HashTable<string,string> network in scanner.network_list) {
			foreach (string key in network.get_keys()) {
				stdout.printf ("%s => %s \n", key, network.lookup(key));
			}
		}
	}

	return 0;
}
