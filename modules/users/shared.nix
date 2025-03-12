{ config, lib, pkgs, ... }: {

	options.users.sharedFolder = lib.mkOption {
		type = lib.types.nullOr lib.types.path;
		default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
			Linux = "/home/shared";
			Darwin = "/Users/Shared";
		};
		description = "Folder with files common across users.";
	};

	config = lib.mkIf (config.users.sharedFolder != null) {

		system.activationScripts.shared = ''
			storeHeading -
		'' + lib.optionalString pkgs.stdenv.isLinux ''
			makeDir 3777:root:sudo '${config.users.sharedFolder}'
		'' + ''
			if ! test -e "''${XDG_STATE_HOME:-$HOME/.local/state}/nix" ; then
				# symlink the Nix profile to the shared folder
				makeDir 755::${lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
					Linux = "sudo";
					Darwin = "admin";
				}} \
					'${config.users.sharedFolder}/.local' \
					'${config.users.sharedFolder}/.local/state' \
					'${config.users.sharedFolder}/.local/state/nix'
				makeLink "''${XDG_STATE_HOME:-$HOME/.local/state}/nix" '${config.users.sharedFolder}/.local/state/nix'
			fi
		'';

		system.activationScripts.profile.deps = [ "shared" ];
	};
}
