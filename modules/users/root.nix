{ config, lib, options, ... }: {

	options.users.root = {

		stagingDirectory = lib.mkOption {
			type = lib.types.nullOr lib.types.str;
			default = "\${XDG_STATE_HOME:-$HOME/.local/state}/rebuild";
			description = "Files for the root account are staged in this directory to check for changes that need to be copied into root’s home.";
		};
		syncCommand = lib.mkOption {
			type = lib.types.str;
			default = ''
				rsync --verbose --recursive --links --perms --times "${toString config.users.root.stagingDirectory}/" ~root/
			'';
			description = "Command to transfer files from the staging directory to root’s home.";
		};
		deletions = lib.mkOption {
			type = lib.types.listOf lib.types.str;
			default = [];
			description = "Files to be deleted from root’s home and the staging directory. Paths are relative.";
		};
	};

	config = lib.mkIf (config.users.root.stagingDirectory != null) {

		system.activationScripts.staging = ''
			storeHeading -

			# set permissions
			if $isLinux ; then makeDir 700 "${config.users.root.stagingDirectory}" ; fi
			if $isDarwin ; then makeDir 750 "${config.users.root.stagingDirectory}" ; fi

			# migrate from default directory, if current setting is different
			if test "${config.users.root.stagingDirectory}" != "${options.users.root.stagingDirectory.default}" ; then
				if test -d "${options.users.root.stagingDirectory.default}" ; then
					printWarning "Default staging directory ${options.users.root.stagingDirectory.default} exists while a different one has been configured: ${config.users.root.stagingDirectory}"
					trace rsync --verbose --archive --update "${options.users.root.stagingDirectory.default}" "${config.users.root.stagingDirectory}"
				fi
			fi

			rootStagingChecksumBefore=$(
				find "${config.users.root.stagingDirectory}" -print0 | \
					LC_ALL=C sort --zero-terminated | \
					tar --create --null --files-from=- --no-recursion 2> /dev/null | \
					cksum
			)
		'';

		system.activationScripts.root = lib.stringAfter [ "staging" ] ''
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
	};
}
