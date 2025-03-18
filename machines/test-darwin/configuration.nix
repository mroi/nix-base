{
	imports = [ ../common.nix ];

	nixpkgs.system = "x86_64-darwin";

	environment.profile = [
		# command line support tools
		"nix-base#arq-restore"
		"nixpkgs#shellcheck"
		"nixpkgs#smartmontools"
	];
}
