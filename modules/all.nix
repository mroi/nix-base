{
	# toplevel activation script and base system setup
	"activate" = ./system/activate.nix;
	"setup" = ./system/setup.nix;

	# Nix setup
	"nixpkgs" = ./nix/nixpkgs.nix;

	# root account, groups, and users
	"root" = ./users/root.nix;
}
