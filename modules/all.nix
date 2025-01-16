{
	# toplevel activation script and base system setup
	"activate" = ./system/activate.nix;
	"setup" = ./system/setup.nix;

	# Nix setup
	"builders" = ./nix/builders.nix;
	"install" = ./nix/install.nix;
	"nixpkgs" = ./nix/nixpkgs.nix;
	"settings" = ./nix/settings.nix;

	# root account, groups, and users
	"groups" = ./users/groups.nix;
	"root" = ./users/root.nix;
	"users" = ./users/users.nix;

	# system environment setup
	"hooks" = ./environment/hooks.nix;
	"services" = ./environment/services.nix;
}
