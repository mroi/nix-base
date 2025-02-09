{
	# base system setup and toplevel scripts
	"activate" = ./system/activate.nix;
	"setup" = ./system/setup.nix;
	"sip" = ./system/sip.nix;

	# Nix setup
	"builders" = ./nix/builders.nix;
	"install" = ./nix/install.nix;
	"nixpkgs" = ./nix/nixpkgs.nix;
	"noinstall" = ./nix/noinstall.nix;
	"settings" = ./nix/settings.nix;

	# root account, groups, and users
	"directory" = ./users/directory.nix;
	"groups" = ./users/groups.nix;
	"root" = ./users/root.nix;
	"users" = ./users/users.nix;

	# network setup
	"firewall" = ./networking/firewall.nix;

	# system environment setup
	"hooks" = ./environment/hooks.nix;
	"profile" = ./environment/profile.nix;
	"rootpaths" = ./environment/rootpaths.nix;
	"services" = ./environment/services.nix;
}
