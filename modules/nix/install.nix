{ config, lib, pkgs, ... }: {

	options.nix = {

		enable = lib.mkEnableOption "Install Nix systemwide." // {
			default = config.system.systemwideSetup;
		};
	};

	config = lib.mkIf config.nix.enable {

		users = {
			users._nix = {
				uid = 600;
				group = "nix";
				description = "Nix Build User";
			};
			groups.nix = {
				gid = 600;
				# explicit group membership is redundant, given the primary group for user _nix
				# but needed by the Nix daemon to enumerate all build users
				members = [ "_nix" ];
				description = "Nix Build Group";
			};
		};

		# setup of user, group, systemd/launchd service duplicated in install script,
		# because the script is run standalone by rebuild when Nix is not yet installed
		system.activationScripts.nix = lib.stringAfter [ "users" "groups" "staging" ] ''
			rootStagingDir=${config.users.root.stagingDirectory}
			${lib.readFile ./install.sh}
		'';

		system.activationScripts.root.deps = [ "nix" ];

		environment.loginHook.nix = lib.optionalString pkgs.stdenv.isDarwin ''
			# mount Nix volume
			if test "$(stat -f %d /)" = "$(stat -f %d /nix)" ; then
				NIX_VOLUME_PASSWORD= # placeholder, will be filled at runtime
				echo "$NIX_VOLUME_PASSWORD" | diskutil quiet apfs unlock Nix -stdinpassphrase -mountpoint /nix
			fi
		'';
	};
}
