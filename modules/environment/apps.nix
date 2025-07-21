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
		apps = lib.mkOption {
			type = lib.types.nullOr (lib.types.listOf (lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = lib.types.strMatching "[a-zA-Z0-9.-]+";
				Darwin = lib.types.int;
			}));
			default = [];
			description = "List of apps to install.";
		};
	};

	config = {

		assertions = [{
			assertion = config.environment.flatpak == "none" || pkgs.stdenv.isLinux;
			message = "Flatpak apps are only supported on Linux";
		}];

		system.activationScripts.apps = lib.mkIf (config.environment.apps != null) (lib.stringAfter [ "volumes" ] (''
			storeHeading 'Installing and removing applications'

			target='${lib.concatLines (map toString config.environment.apps)}'
		'' + lib.optionalString pkgs.stdenv.isDarwin ''
			current=$(mdfind 'kMDItemAppStoreAdamID > 0' | while read -r app ; do
				mdls -attr kMDItemAppStoreAdamID -raw "$app" ; echo
			done)

			# install missing apps
			mas=
			mas() { test "$mas" || mas=${pkgs.lazyBuild pkgs.mas}/bin/mas ; "$mas" "$@" ; }
			forTarget() {
				if ! hasLine "$current" "$1" ; then
					trace mas install "$1"
				fi
			}
			forLines "$target" forTarget

			# remove unneeded apps
			forCurrent() {
				if ! hasLine "$target" "$1" ; then
					location=$(mdfind "kMDItemAppStoreAdamID = $1")
					if test -d "$location" ; then
						trace sudo rm -rf "$location"
					else
						printError "Could not find app $1 at '$location'"
					fi
				fi
			}
			forLines "$current" forCurrent
		'' + lib.optionalString (pkgs.stdenv.isLinux && config.environment.flatpak != "none") ''
			current=$(flatpak --${config.environment.flatpak} list --app --columns=application)

			# install missing apps
			forTarget() {
				if ! hasLine "$current" "$1" ; then
					${lib.getAttr config.environment.flatpak {
						system = "trace sudo flatpak --system install --app \"$1\"";
						user = "trace flatpak --user install --app \"$1\"";
					}}
				fi
			}
			forLines "$target" forTarget

			# remove unneeded apps
			forCurrent() {
				if ! hasLine "$target" "$1" ; then
					${lib.getAttr config.environment.flatpak {
						system = "trace sudo flatpak --system uninstall --app \"$1\"";
						user = "trace flatpak --user uninstall --app \"$1\"";
					}}
				fi
			}
			forLines "$current" forCurrent
		''));

		system.updateScripts.apps = lib.stringAfter [ "packages" ] (''
			storeHeading -
		'' + lib.optionalString pkgs.stdenv.isDarwin ''
			trace "${pkgs.lazyBuild pkgs.mas}/bin/mas" upgrade
		'' + lib.getAttr config.environment.flatpak {
			system = ''
				trace sudo flatpak --system update || true
				trace sudo flatpak --system uninstall --unused || true
			'';
			user = ''
				trace flatpak --user update || true
				trace flatpak --user uninstall --unused || true
			'';
			none = "";
		});

		system.cleanupScripts.apps = lib.stringAfter [ "packages" ] (''
			storeHeading 'Cleaning applications'
		'' + lib.getAttr config.environment.flatpak {
			system = ''
				trace sudo flatpak --system uninstall --assumeyes --unused
				trace sudo flatpak --system repair
			'';
			user = ''
				trace flatpak --user uninstall --assumeyes --unused
				trace flatpak --user repair
			'';
			none = "";
		});
	};
}
