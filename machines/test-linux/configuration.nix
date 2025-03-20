{
	imports = [ ../common.nix ];

	nixpkgs.system = "x86_64-linux";
	networking.hostName = "test-linux";

	users.guest.enable = false;

	environment.flatpak = "none";

	environment.profile = [
		# Unison file sync
		"nix-base#unison"
		"github:mroi/aws-ssh-proxy/unison-sync#unison-sync"
	];
}
