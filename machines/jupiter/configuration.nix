{
	imports = [ ../common.nix ];

	nixpkgs.system = "x86_64-darwin";

	environment.profile = [
		# command line support tools
		"nix-base#arq-restore"
		"nixpkgs#shellcheck"
		"nixpkgs#smartmontools"

		# video
		"github:mroi/video-tools#video-tools"
		"github:mroi/video-tools#ffmpeg"

		# tools for research work
		"nix-base#texlive"
	];
}
