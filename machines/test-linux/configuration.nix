{ lib, ...}: {

	imports = [ ../common.nix ];

	nixpkgs.system = "x86_64-linux";

	environment.profile = [
		# Unison file sync
		"nix-base#unison"
		"github:mroi/aws-ssh-proxy/unison-sync#unison-sync"
	];
}
