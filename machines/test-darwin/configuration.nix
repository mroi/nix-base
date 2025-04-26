{
	imports = [ ../common.nix ];

	nixpkgs.system = "x86_64-darwin";
	networking.hostName = "test-darwin";

	services.sshProxy.enableClient = true;
	services.sshProxy.enableServer = true;
	services.unison.awsSync = true;

	environment.profile = [
		# command line support tools
		"nix-base#arq-restore"
		"nixpkgs#shellcheck"
		"nixpkgs#smartmontools"
	];
}
