{
	imports = [ ../common.nix ];

	nixpkgs.system = "x86_64-linux";

	system.systemwideSetup = false;

	environment.profile = [
		# Unison file sync
		"nix-base#unison"
	];
}
