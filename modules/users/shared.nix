{ config, lib, pkgs, ... }: {

	options.users.shared = {
		folder = lib.mkOption {
			type = lib.types.nullOr lib.types.path;
			default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = "/home/shared";
				Darwin = "/Users/Shared";
			};
			description = "Folder with files common across users.";
		};
		group = lib.mkOption {
			type = lib.types.passwdEntry lib.types.str;
			default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = "adm";
				Darwin = "admin";
			};
			description = "Files in the shared folder belong to this group.";
		};
	};

	config = lib.mkIf (config.users.shared.folder != null) {

		system.activationScripts.shared = ''
			storeHeading -
		'' + lib.optionalString pkgs.stdenv.isLinux ''
			makeDir 3777:root:${config.users.shared.group} '${config.users.shared.folder}'
		'' + lib.optionalString (config.environment.profile != null) ''
			storeHeading 'Redirecting Nix profile to shared folder'
			stateDir=''${XDG_STATE_HOME:-$HOME/.local/state}
			if ! test -e "$stateDir/nix" ; then
				# symlink the Nix profile to the shared folder
				makeDir 755::${lib.optionalString pkgs.stdenv.isDarwin "admin"} \
					'${config.users.shared.folder}/${config.users.stateDir}/nix'
				makeDir 755 "$stateDir"
				makeLink "$stateDir/nix" '${config.users.shared.folder}/${config.users.stateDir}/nix'
			fi
		'' + lib.optionalString pkgs.stdenv.isDarwin ''
			# prompt the user to delete relocated items
			find "${config.users.shared.folder}/"*Relocated\ Items* > relocated 2> /dev/null || true
			interactiveDeletes relocated 'These files got moved to ${config.users.shared.folder} by a macOS update.'
			rm relocated
		'';

		system.activationScripts.profile = lib.mkIf (config.environment.profile != null) {
			deps = [ "shared" ];
		};

		system.cleanupScripts.shared = ''
			storeHeading 'Fixing file groups in shared folder'
			find '${config.users.shared.folder}' \
				! -group 0 ! -group ${config.users.shared.group} \
				! -path '${config.users.shared.folder}/${config.users.stateDir}/nix/profiles/profile*' | \
				while read -r file ; do trace chgrp -h ${config.users.shared.group} "$file" ; done
		'';
	};
}
