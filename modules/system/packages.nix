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

			# purge half-installed packages
			dpkg-query --showformat ''\'''${Status}|''${Package}\n' --show | \
				sed '
					/^install ok installed/d
					/^unknown ok not-installed/d
					s/^[^|]*|//
					s/^/dpkg --purge /
				' | \
				interactiveCommands incomplete \
					'These packages are in an incomplete installation state.' \
					'They will be uninstalled unless lines are commented or removed.'
		'');

		system.cleanupScripts.files.text = lib.mkOrder 2000 (''
			# system-level package information should overwrite any other file source,
			# so this script must be last of all file-info collection fragments
			{
				echo 'BEGIN IMMEDIATE TRANSACTION;'
				printInfo 'Collecting installed files: system-level packages'

		'' + lib.optionalString pkgs.stdenv.isLinux ''

				find /var/lib/dpkg/info -maxdepth 1 -name '*.list' | while read -r list ; do
					name=''${list##*/}
					name=''${name%.list}
					{
						# files from the package’s file list, merged to /usr
						sed '
							s|^/bin/|/usr/bin/|
							s|^/lib/|/usr/lib/|
							s|^/lib64/|/usr/lib64/|
							s|^/sbin/|/usr/sbin/|
						' "$list"
						# file diversions installed by the package
						sed -n "/^''${name%%:*}\$/ { x ; p ; } ; h" /var/lib/dpkg/diversions
					} | addSource dpkg "$name" "WHERE path = '&'"
				done

				# dpkg alternatives
				find /var/lib/dpkg/alternatives -mindepth 1 -maxdepth 1 | while read -r file ; do
					sed -n '1,/^$/ { /^\//p ; }' "$file"
				done | sed '
					s|^/bin/|/usr/bin/|
					s|^/lib/|/usr/lib/|
					s|^/lib64/|/usr/lib64/|
					s|^/sbin/|/usr/sbin/|
				' | addSource dpkg alternatives "WHERE path = '&'"

		'' + lib.optionalString pkgs.stdenv.isDarwin ''

				# shellcheck disable=SC2043
				for volume in / ; do
					# sort packages by install time so later packages overwrite earlier ones in the database
					pkgutil --volume "$volume" --packages | while read -r package ; do
						pkgutil --volume "$volume" --pkg-info "$package" | \
							awk "BEGIN { FS = \": *\" ; } /^install-time:/ { print \$2 \"\t\" \"$package\" }"
					done | sort -n | cut -f2- | while read -r package ; do
						basepath=$(pkgutil --volume "$volume" --pkg-info "$package" | sed -n '/^location:/ { s/^.*: *// ; p ; }')
						basepath=$(cd "$volume$basepath" && pwd -P || echo "$volume$basepath")
						if test "$basepath" = "''${basepath%/}" ; then basepath=$basepath/ ; fi
						pkgutil --volume "$volume" --files "$package" | awk "{ print \"$basepath\" \$0 }" | \
							addSource pkg "$package" "WHERE path = '&'"
					done
				done

		'' + ''

				echo 'COMMIT TRANSACTION;'
			} | runSQL
		'');
	};
}
