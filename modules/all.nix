{
	# toplevel script build
	"portable" = ./build/portable.nix;
	"rebuild" = ./build/rebuild.nix;
	"scripts" = ./build/scripts.nix;

	# underlying system setup
	"setup" = ./system/setup.nix;

	# Nix setup
	"builders" = ./nix/builders.nix;
	"install" = ./nix/install.nix;
	"nixpkgs" = ./nix/nixpkgs.nix;
	"settings" = ./nix/settings.nix;
	"store" = ./nix/store.nix;

	# volumes and file systems
	"volumes" = ./filesystems/volumes.nix;

	# root account, groups, and users
	"directory" = ./users/directory.nix;
	"groups" = ./users/groups.nix;
	"guest" = ./users/guest.nix;
	"root" = ./users/root.nix;
	"users" = ./users/users.nix;

	# network setup
	"firewall" = ./networking/firewall.nix;

	# system environment setup
	"hooks" = ./environment/hooks.nix;
	"patches" = ./environment/patches.nix;
	"profile" = ./environment/profile.nix;
	"rootpaths" = ./environment/rootpaths.nix;
	"services" = ./environment/services.nix;

	# security settings
	"password" = ./security/password.nix;
	"sip" = ./security/sip.nix;
	"sudo" = ./security/sudo.nix;

	# service configurations
	"ssh" = ./services/ssh.nix;
}
