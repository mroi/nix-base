{
	imports = [ ../common.nix ];

	nixpkgs.system = "x86_64-darwin";
	networking.hostName = "test-darwin";

	environment.profile = [
		# command line support tools
		"nix-base#arq-restore"
		"nixpkgs#shellcheck"
		"nixpkgs#smartmontools"
	];

	services.sshProxy.enableClient = true;
	services.sshProxy.enableServer = true;
}
