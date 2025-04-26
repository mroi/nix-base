{
	imports = [ ../common.nix ];

	nixpkgs.system = "x86_64-linux";
	networking.hostName = "test-linux";

	users.guest.enable = false;

	environment.flatpak = "none";

	# cloud sync
	services.unison.awsSync = true;
}
