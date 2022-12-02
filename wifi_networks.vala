/* Search for wireless networks that are known to the computer the program is
 * running on, connect to each, and output the default gateway for each network.
 * 
 * Exit code (0: success, 1:failure)
 */

using Gee;

/* Check wireless network configuration files */
int main () {
	var file_list = new ArrayList<string>();
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
			stdout.printf("ERROR: not enough privileges, please run as root");
			return 1;
		} else {
			/* Clean up for empty elements */
			foreach (string filename in standard_output.split ("\n")) {
				if (filename != "") {
					file_list.add(filename);
				}
			}
		}
	} catch (SpawnError e) {
		stderr.printf("%s\n", e.message);
	}

	/* Read each NetworkManager file */
	foreach (string filename in file_list) {
		//stdout.printf ("%s\n", filename);

		try {
			string file_contents;
			FileUtils.get_contents (
				"%s/%s".printf(network_manager_config_location, filename),
				out file_contents
			);

			//stdout.printf ("%s \n---\n%s", filename, file_contents);
			if ("type=wifi" in file_contents) {
				stdout.printf ("%s \n---\n%s", filename, file_contents);
			}
		} catch (FileError e) {
			stderr.printf ("%s\n", e.message);
		}
	}

	return 0;
}
