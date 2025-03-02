{ config, lib, pkgs, ... }: {

	options.nix.builders = {

		linux = lib.mkEnableOption "Linux builder VM" // {
			default = pkgs.stdenv.isDarwin;
		};
	};

	config = lib.mkIf (config.nix.enable && config.nix.builders.linux) {

		nix.settings.builders = [
			"builder-linux aarch64-linux,x86_64-linux - - - big-parallel,kvm"
		];
		nix.ssh.config = lib.concatLines [
			"Host builder-linux"
			"Hostname localhost"
			"Port 33022"
			"User builder"
		];
		nix.ssh.knownHosts = lib.concatLines [
			"[localhost]:33022 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBWcxb/Blaqt1auOtE+F8QUWrUotiC5qBJ+UuEWdVCb"
		];
		nix.ssh.keygen = true;
		system.activationScripts.nix.text = lib.mkAfter ''
			if ! test -f /nix/var/ssh/builder_ed25519.pub ; then
				# offer the SSH public key under the name expected by the Linux builder
				trace sudo ln /nix/var/ssh/id_ed25519.pub /nix/var/ssh/builder_ed25519.pub
			fi
		'';
	};
}
