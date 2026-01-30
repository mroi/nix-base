{ config, lib, pkgs, ... }: {

	options.system.packages = lib.mkOption {
		type = lib.types.nullOr (lib.types.listOf (lib.types.either
			lib.types.str
			(lib.types.submodule { options = {
				name = lib.mkOption {
					type = lib.types.str;
					description = "The name of the package.";
				};
				includeRecommends = lib.mkEnableOption "recommended dependencies";
			};})
		));
		default = [];
		description = "System-level packages to install in the underlying system.";
	};

	config = lib.mkIf (config.system.packages != null) {

		assertions = [{
			assertion = (config.system.packages != null && config.system.packages != []) -> pkgs.stdenv.isLinux;
			message = "System-level package installation is currently only supported on Linux";
		}];

		system.activationScripts.packages = let

			packages = map (x: if lib.isString x then
				{ name = x; includeRecommends = false; } else x) config.system.packages;

			installScript = package: lib.optionalString pkgs.stdenv.isLinux ''
				if ! dpkg --status ${package.name} > /dev/null 2>&1 ; then
					trace sudo apt-get install ${if package.includeRecommends then "" else "--no-install-recommends "}${package.name}
				fi
			'';

		in ''
			storeHeading 'Installing packages in the underlying system'

			${lib.concatLines (map installScript packages)}
		'';

		system.updateScripts.packages = lib.optionalString pkgs.stdenv.isLinux ''
			storeHeading -
			trace sudo apt-get update --quiet
			trace sudo apt-get dist-upgrade || true
			trace sudo apt-get autopurge || true
			trace sudo apt-get clean
		'';

		system.cleanupScripts.packages = lib.stringAfter [ "volumes" ] (lib.optionalString pkgs.stdenv.isLinux ''
			storeHeading 'Cleaning system-level packages'
			trace sudo apt-get --assume-yes autopurge
			trace sudo apt-get clean
			trace sudo apt-cache gencaches
			trace sudo apt-get --quiet check
			trace sudo dpkg --clear-avail
			trace sudo dpkg --audit
		'');
	};
}
