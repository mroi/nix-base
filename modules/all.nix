{
	# toplevel script build
	"portable" = ./build/portable.nix;
	"rebuild" = ./build/rebuild.nix;
	"scripts" = ./build/scripts.nix;

	# underlying system setup
	"boot" = ./system/boot.nix;
	"drift" = ./system/drift.nix;
	"nvram" = ./system/nvram.nix;
	"packages" = ./system/packages.nix;
	"setup" = ./system/setup.nix;
	"updates" = ./system/updates.nix;

	# Nix setup
	"builders" = ./nix/builders.nix;
	"install" = ./nix/install.nix;
	"nixpkgs" = ./nix/nixpkgs.nix;
	"settings" = ./nix/settings.nix;
	"store" = ./nix/store.nix;

	# volumes and file systems
	"volumes" = ./filesystems/volumes.nix;

	# root account, groups, and users
	"accounts" = ./users/accounts.nix;
	"directory" = ./users/directory.nix;
	"groups" = ./users/groups.nix;
	"guest" = ./users/guest.nix;
	"root" = ./users/root.nix;
	"shared" = ./users/shared.nix;
	"shell" = ./users/shell.nix;
	"users" = ./users/users.nix;

	# network setup
	"firewall" = ./networking/firewall.nix;
	"hostname" = ./networking/hostname.nix;

	# timekeeping setup
	"timezone" = ./time/timezone.nix;

	# system environment setup
	"apps" = ./environment/apps.nix;
	"bundles" = ./environment/bundles.nix;
	"extensions" = ./environment/extensions.nix;
	"hooks" = ./environment/hooks.nix;
	"patches" = ./environment/patches.nix;
	"profile" = ./environment/profile.nix;
	"rootpaths" = ./environment/rootpaths.nix;
	"services" = ./environment/services.nix;

	# security settings
	"password" = ./security/password.nix;
	"prefsec" = ./security/prefsec.nix;
	"sip" = ./security/sip.nix;
	"sudo" = ./security/sudo.nix;

	# service configurations
	"arq" = ./services/arq.nix;
	"awssync" = ./services/awssync.nix;
	"ssh" = ./services/ssh.nix;
	"sshproxy" = ./services/sshproxy.nix;
	"timemachine" = ./services/timemachine.nix;
	"unison" = ./services/unison.nix;

	# application programs
	"develop" = ./programs/develop.nix;
	"xcode" = ./programs/xcode.nix;
}
