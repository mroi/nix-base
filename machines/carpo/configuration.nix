{
	imports = [ ../common.nix ];

	nixpkgs.system = "x86_64-darwin";

	environment.profile = [
		# command line support tools
		"nix-base#arq-restore"
		"nix-base#unison-fsmonitor"
		"nixpkgs#smartmontools"

		# high resolution for screen sharing
		"nix-base#hires"

		# tools for research work
		"nix-base#texlive"
		"nixpkgs#kubectl"
		"nixpkgs#minicom"
		"nixpkgs#openconnect"
		"nixpkgs#synergyWithoutGUI"
	];
}
