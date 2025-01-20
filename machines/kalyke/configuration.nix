{ lib, ...}: {

	imports = [ ../common.nix ];

	nixpkgs.system = "x86_64-linux";

	# use BIOS as additional binary Nix cache
	nix = {
		settings = {
			trusted-substituters = [ "ssh://bios.local"	];
			trusted-public-keys = [
				"cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
				"bios-1:+redacted+AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
			];
		};
		ssh = {
			config = lib.concatLines [
				"Host bios.local"
				"User michael"
				"IdentityFile /nix/var/ssh/id_ed25519"
			];
			knownHosts = lib.concatLines [
				"bios.local ssh-ed25519 <redacted>"
			];
			keygen = true;
		};
	};
}
