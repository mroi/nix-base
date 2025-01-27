{ lib, pkgs, ... }: {

	environment.profile = [
		"nix-base#nix"
		"nix-base#fish"
		"nixpkgs#micro"
	];
}
