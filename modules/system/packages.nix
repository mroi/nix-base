{ config, lib, pkgs, ... }: {

	options.system.packages = lib.mkOption {
		type = lib.types.nullOr (lib.types.listOf lib.types.str);
		default = [];
		description = "System-level packages to install in the underlying system.";
	};

	config = lib.mkIf (config.system.packages != null) {

		assertions = [{
			assertion = config.system.packages == null || config.system.packages == [] || pkgs.stdenv.isLinux;
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
						# files directly from the package’s file list
						cat "$list"
						# file diversions installed by the package
						sed -n "/^''${name%%:*}\$/ { x ; p ; } ; h" /var/lib/dpkg/diversions
					} | addSource dpkg "$name" "WHERE path = '\1'"
				done

				# dpkg alternatives
				find /var/lib/dpkg/alternatives -mindepth 1 -maxdepth 1 | while read -r file ; do
					sed -n '1,/^$/ { /^\//p ; }' "$file"
				done | addSource dpkg alternatives "WHERE path = '\1'"

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
							addSource pkg "$package" "WHERE path = '\1'"
					done
				done

		'' + ''

				echo 'COMMIT TRANSACTION;'
			} | runSQL
		'');
	};
}
