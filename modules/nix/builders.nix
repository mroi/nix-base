{ config, lib, pkgs, ... }: {

	options.nix.builders = {

		linux = lib.mkEnableOption "Linux builder VM" // {
			default = pkgs.stdenv.isDarwin;
		};
	};

	config = lib.mkIf (config.nix.enable && config.nix.builders.linux) {

		# should be localhost, but that does not work in Nix 2.31.2
		# https://github.com/NixOS/nix/pull/14178/commits/823c630b2e0ee5ffe07152ff3f3eddfcfe216fe1
		nix.settings.builders = [
			"ssh://builder@127.0.0.1:33022 aarch64-linux,x86_64-linux - - - big-parallel,kvm"
		];
		nix.ssh.knownHosts = lib.concatLines [
			"[127.0.0.1]:33022 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBWcxb/Blaqt1auOtE+F8QUWrUotiC5qBJ+UuEWdVCb"
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
