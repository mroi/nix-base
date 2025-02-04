{
	# base system setup and toplevel scripts
	"rebuild" = ./system/rebuild.nix;
	"scripts" = ./system/scripts.nix;
	"setup" = ./system/setup.nix;

	# Nix setup
	"builders" = ./nix/builders.nix;
	"install" = ./nix/install.nix;
	"nixpkgs" = ./nix/nixpkgs.nix;
	"runnable" = ./nix/runnable.nix;
	"settings" = ./nix/settings.nix;

	# root account, groups, and users
	"directory" = ./users/directory.nix;
	"groups" = ./users/groups.nix;
	"root" = ./users/root.nix;
	"users" = ./users/users.nix;

	# network setup
	"firewall" = ./networking/firewall.nix;

	# security settings
	"sip" = ./security/sip.nix;

	# system environment setup
	"hooks" = ./environment/hooks.nix;
	"patches" = ./environment/patches.nix;
	"profile" = ./environment/profile.nix;
	"rootpaths" = ./environment/rootpaths.nix;
	"services" = ./environment/services.nix;

	# service configurations
	"ssh" = ./services/ssh.nix;
}
