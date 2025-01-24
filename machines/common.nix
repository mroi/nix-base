{ lib, pkgs, ... }: {

	environment.profile = [
		"nix-base#nix"
		"nix-base#fish"
	] ++ lib.optionals pkgs.stdenv.isDarwin [
		"nixpkgs#nano"
	];
}
