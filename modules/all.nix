{
	# toplevel script build
	"portable" = ./build/portable.nix;
	"rebuild" = ./build/rebuild.nix;
	"scripts" = ./build/scripts.nix;

	# underlying system setup
	"boot" = ./system/boot.nix;
	"distro" = ./system/distro.nix;
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
	"filevault" = ./filesystems/filevault.nix;
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
	"interfaces" = ./networking/interfaces.nix;

	# timekeeping setup
	"timezone" = ./time/timezone.nix;

	# system environment setup
	"apps" = ./environment/apps.nix;
	"bundles" = ./environment/bundles.nix;
	"config" = ./environment/config.nix;
	"extensions" = ./environment/extensions.nix;
	"hooks" = ./environment/hooks.nix;
	"patches" = ./environment/patches.nix;
	"profile" = ./environment/profile.nix;
	"rootpaths" = ./environment/rootpaths.nix;
	"services" = ./environment/services.nix;

	# security settings
	"checks" = ./security/checks.nix;
	"gatekeeper" = ./security/gatekeeper.nix;
	"password" = ./security/password.nix;
	"pki" = ./security/pki.nix;
	"prefsec" = ./security/prefsec.nix;
	"sudo" = ./security/sudo.nix;
	"xprotect" = ./security/xprotect.nix;

	# service configurations
	"arq" = ./services/arq.nix;
	"awssync" = ./services/awssync.nix;
	"ollama" = ./services/ollama.nix;
	"ssh" = ./services/ssh.nix;
	"sshkeys" = ./services/sshkeys.nix;
	"sshproxy" = ./services/sshproxy.nix;
	"timemachine" = ./services/timemachine.nix;
	"unison" = ./services/unison.nix;

	# application programs
	"affinity" = ./programs/affinity.nix;
	"develop" = ./programs/develop.nix;
	"emulators" = ./programs/emulators.nix;
	"sfsymbols" = ./programs/sfsymbols.nix;
	"utilities" = ./programs/utilities.nix;
	"vmware" = ./programs/vmware.nix;
	"writing" = ./programs/writing.nix;
	"xcode" = ./programs/xcode.nix;
}
