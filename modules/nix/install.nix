{ config, lib, pkgs, ... }: {

	options.nix = {

		enable = lib.mkEnableOption "Install Nix systemwide." // {
			default = config.system.systemwideSetup;
		};
		config = lib.mkOption {
			type = lib.types.lines;
			description = "The Nix configuration options for `/nix/nix.conf`.";
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

		environment.services.nix-daemon = {
			label = "org.nixos.nix-daemon";
			description = "Nix Package Manager Daemon";
			command = "${lib.optionalString pkgs.stdenv.isDarwin "/var"}/root/.nix/profile/bin/nix --extra-experimental-features nix-command daemon";
			environment = [
				"NIX_CONF_DIR=/nix"
				"NIX_SSHOPTS=-F /nix/var/ssh/config"
				"NIX_SSL_CERT_FILE=${lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
					Linux = "/etc/ssl/certs/ca-certificates.crt";
					Darwin = "/etc/ssl/cert.pem";
				}}"
			] ++ lib.optionals pkgs.stdenv.isDarwin [
				# Starting with Nix 2.25, OBJC_DISABLE_INITIALIZE_FORK_SAFETY will be unnecessary
				(assert lib.strings.compareVersions pkgs.nix.version "2.25" < 0;
				"OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES")
			] ++ [
				"TMPDIR=/nix/var/tmp"
				"XDG_CACHE_HOME=/nix/var"
			];
			group = "nix";
			socket = lib.mkIf pkgs.stdenv.isLinux "/nix/var/nix/daemon-socket/socket";
			waitForPath = "/nix/store";
		};

		# setup of user, group, nix.conf, systemd/launchd service duplicated in install script,
		# because the script is run standalone by rebuild when Nix is not yet installed
		system.activationScripts.nix = lib.stringAfter [ "users" "groups" "staging" ] ''
			rootStagingDir=${config.users.root.stagingDirectory}
			nixConfigFile=${pkgs.writeText "nix.conf" config.nix.config}
			${lib.readFile ./install.sh}
		'';

		system.activationScripts.root.deps = [ "nix" ];
		system.activationScripts.services.deps = [ "nix" ];

		environment.loginHook.nix = lib.optionalString pkgs.stdenv.isDarwin ''
			# mount Nix volume
			if test "$(stat -f %d /)" = "$(stat -f %d /nix)" ; then
				NIX_VOLUME_PASSWORD= # placeholder, will be filled at runtime
				echo "$NIX_VOLUME_PASSWORD" | diskutil quiet apfs unlock Nix -stdinpassphrase -mountpoint /nix
			fi
		'';
	};
}
