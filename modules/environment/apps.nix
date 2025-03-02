{ config, pkgs, lib, ... }: {

	options.environment = {
		flatpak = lib.mkOption {
			type = lib.types.enum [ "system" "user" "none" ];
			default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = "system";
				Darwin = "none";
			};
			description = "Manage Flatpak apps in system or user mode.";
		};
	};

	config = {

		system.updateScripts.apps = lib.stringAfter [ "packages" ] (''
			storeHeading -
		'' + lib.getAttr config.environment.flatpak {
			system = ''
				trace sudo flatpak update || true
				trace sudo flatpak uninstall --unused || true
			'';
			user = ''
				trace flatpak update --user || true
				trace flatpak uninstall --user --unused || true
			'';
			none = "";
		});

		system.cleanupScripts.apps = lib.stringAfter [ "packages" ] (''
			storeHeading 'Cleaning applications'
		'' + lib.getAttr config.environment.flatpak {
			system = ''
				trace sudo flatpak uninstall --assumeyes --unused
				trace sudo flatpak repair
			'';
			user = ''
				trace flatpak uninstall --assumeyes --user --unused
				trace flatpak repair --user
			'';
			none = "";
		});
	};
}
