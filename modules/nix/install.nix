{ config, lib, pkgs, ... }: {

	options.nix = {

		enable = lib.mkEnableOption "Nix systemwide" // { default = true; };
		config = lib.mkOption {
			type = lib.types.lines;
			description = "The Nix configuration options for `/nix/nix.conf`.";
		};
		ssh = {
			config = lib.mkOption {
				type = lib.types.lines;
				description = "Configuration options for SSH operations performed by the Nix daemon";
			};
			knownHosts = lib.mkOption {
				type = lib.types.lines;
				default = "";
				description = "Known host keys for SSH operations performed by the Nix daemon";
			};
			keygen = lib.mkEnableOption "Nix daemon SSH identity creation";
		};
	};

	config = lib.mkIf config.nix.enable {

		fileSystems."/nix" = lib.mkIf pkgs.stdenv.isDarwin {
			fsType = "APFSX";
			encrypted = true;
			ownership = true;
			hidden = true;
		};

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

		environment.rootPaths = [ (lib.getExe pkgs.nix) ];

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
				"TMPDIR=/nix/var/tmp"
				"XDG_CACHE_HOME=/nix/var"
			];
			group = "nix";
			socket = lib.mkIf pkgs.stdenv.isLinux "/nix/var/nix/daemon-socket/socket";
			waitForPath = "/nix/store";
		};

		nix.ssh.config = lib.concatLines ([
			"UserKnownHostsFile /nix/var/ssh/known_hosts"
		] ++ lib.optionals config.nix.ssh.keygen [
			"IdentityFile /nix/var/ssh/id_ed25519"
		]);

		# setup of volume, user, group, nix.conf, systemd/launchd service duplicated in install script,
		# because the script is run standalone by rebuild when Nix is not yet installed
		system.activationScripts.nix = lib.stringAfter [ "volumes" "users" "groups" "staging" ] (''
			rootStagingDir=${config.users.root.stagingDirectory}
			nixConfigFile=${pkgs.writeText "nix.conf" config.nix.config}
			sshConfigFile=${pkgs.writeText "ssh-config" config.nix.ssh.config}
			sshKnownHostsFile=${pkgs.writeText "ssh-known_hosts" config.nix.ssh.knownHosts}
			${lib.readFile ./install.sh}
		'' + lib.optionalString config.nix.ssh.keygen ''
			if ! test -f /nix/var/ssh/id_ed25519 ; then
				trace sudo ssh-keygen -q -t ed25519 -N ''' -C ''' -f /nix/var/ssh/id_ed25519
				makeFile 600:root:nix /nix/var/ssh/id_ed25519
			fi
		'');

		system.activationScripts.services.deps = [ "nix" ];
	};
}
