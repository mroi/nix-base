{ config, lib, pkgs, ... }: {

	options.system.packages = lib.mkOption {
		type = lib.types.nullOr (lib.types.listOf lib.types.str);
		default = [];
		description = "System-level packages to install in the underlying system.";
	};

	config = lib.mkIf (config.system.packages != null) {

		assertions = [{
			assertion = (config.system.packages != null && config.system.packages != []) -> pkgs.stdenv.isLinux;
			message = "System-level package installation is currently only supported on Linux";
		}];

		system.activationScripts.packages = let

			installScript = package: lib.optionalString pkgs.stdenv.isLinux ''
				if ! dpkg --status ${package} > /dev/null 2>&1 ; then
					trace sudo apt-get install --no-install-recommends ${package}
				fi
			'';

		in ''
			storeHeading 'Installing packages in the underlying system'

			${lib.concatLines (map installScript config.system.packages)}
		'';

		system.updateScripts.packages = lib.optionalString pkgs.stdenv.isLinux ''
			storeHeading -
			trace sudo apt-get update --quiet
			trace sudo apt-get dist-upgrade --no-install-recommends || true
			trace sudo apt-get autoremove --purge || true
			trace sudo apt-get clean
		'';

		system.cleanupScripts.packages = lib.stringAfter [ "volumes" ] (lib.optionalString pkgs.stdenv.isLinux ''
			storeHeading 'Cleaning system-level packages'
			trace sudo apt-get --assume-yes autoremove --purge
			trace sudo apt-get clean
			trace sudo apt-cache gencaches
			trace sudo apt-get --quiet check
			trace sudo dpkg --clear-avail
			trace sudo dpkg --audit
		'');
	};
}
