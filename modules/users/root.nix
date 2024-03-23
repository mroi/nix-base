{ config, lib, ... }: {

	options.users.root = {

		stagingDirectory = lib.mkOption {
			type = lib.types.str;
			default = "\${XDG_STATE_HOME:-$HOME/.local/state}/rebuild";
			description = "Files for the root account are staged in this directory to check for changes that need to be copied into root’s home.";
		};
		syncCommand = lib.mkOption {
			type = lib.types.str;
			default = ''
				rsync --verbose --recursive --links --perms --times "${config.users.root.stagingDirectory}/" ~root/
			'';
			description = "Command to transfer files from the staging directory to root’s home.";
		};
		deletions = lib.mkOption {
			type = lib.types.listOf lib.types.str;
			default = [];
			description = "Files to be deleted from root’s home and the staging directory. Paths are relative.";
		};
	};

	config.system.activationScripts.staging = ''
		storeHeading

		# set up staging directory
		if ! test -d "${config.users.root.stagingDirectory}" ; then
			trace mkdir -p "${config.users.root.stagingDirectory}"
		fi
		rootStagingChecksumBefore=$(
			find "${config.users.root.stagingDirectory}" -print0 | \
				LC_ALL=C sort --zero-terminated | \
				tar --create --null --files-from=- --no-recursion 2> /dev/null | \
				cksum
		)
	'';

	config.system.activationScripts.root = lib.stringAfter [ "staging" ] ''
		storeHeading "Updating files in root’s home directory"

		rootStagingChecksumAfter=$(
			find "${config.users.root.stagingDirectory}" -print0 | \
				LC_ALL=C sort --zero-terminated | \
				tar --create --null --files-from=- --no-recursion 2> /dev/null | \
				cksum
		)

		if test "$rootStagingChecksumBefore" != "$rootStagingChecksumAfter" ; then
			trace sudo ${config.users.root.syncCommand}
		fi

		for file in ${lib.escapeShellArgs config.users.root.deletions} ; do
			test -e "${config.users.root.stagingDirectory}/$file" || continue
			sudo rm -rf ~root/"$file"
			rm -rf "${config.users.root.stagingDirectory}/$file"
		done
	'';
}
