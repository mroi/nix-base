{ config, lib, pkgs, ... }: {

	options.services.openssh = {
		enable = lib.mkOption {
			type = lib.types.nullOr lib.types.bool;
			default = true;
			description = "Enable SSH server.";
		};
		harden = lib.mkEnableOption "only key-based authentication with SSH" // { default = true; };
	};

	config = lib.mkIf (config.services.openssh.enable != null) {

		system.packages = lib.mkIf pkgs.stdenv.isLinux [ "openssh-server" ];

		system.activationScripts.ssh = lib.stringAfter [ "packages" ] (''
			storeHeading 'SSH server setup'

			enable=${toString config.services.openssh.enable}
		'' + lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
			Linux = ''
				running=$(if systemctl is-enabled ssh.service > /dev/null 2>&1 ; then echo 1 ; fi)
				case "$enable,$running" in
					1,) trace sudo systemctl enable --now ssh.service ;;
					,1)	trace sudo systemctl disable --now ssh.service ;;
				esac
			'';
			Darwin = ''
				running=$(if launchctl print system/com.openssh.sshd > /dev/null 2>&1 ; then echo 1 ; fi)
				case "$enable,$running" in
					1,) trace sudo systemsetup -setremotelogin on ;;
					,1) trace sudo systemsetup -setremotelogin off ;;
				esac
			'';
		});

		system.activationScripts.patches.deps = [ "ssh" ];

		environment.patches = lib.mkIf config.services.openssh.harden [{
			patch = ./ssh-public-key-only.patch;
			postCommand = "restartService sshd";
		}];
	};
}
