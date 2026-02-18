{ config, lib, pkgs, ... }: {

	config = let

		packagesWithRecommends = lib.pipe config.system.packages [
			(map (x: if lib.isString x then { name = x; includeRecommends = false; } else x))
			(lib.filter (x: x.includeRecommends))
			(map (x: x.name))
		];

		packagesWithoutRecommends = lib.pipe config.system.packages [
			(map (x: if lib.isString x then { name = x; includeRecommends = false; } else x))
			(lib.filter (x: ! x.includeRecommends))
			(map (x: x.name))
		];

		markPackagesUsed = packages: types: let
			typesClause = lib.concatStringsSep " OR " (map (x: "prev.type = '${x}'") types);
		in ''
			# mark listed packages as used
			{
				${lib.pipe packages [
					(map (x: "echo \"UPDATE depends SET used = TRUE WHERE package = '${x}';\""))
					lib.concatLines
				]}
				:  # empty command in case the list of packages is empty
			} | runSQL

			# iteratively mark dependencies of used packages as used
			changes=1
			while test "$changes" -gt 0 ; do
				changes=$({
					echo 'UPDATE depends AS next SET used = TRUE WHERE EXISTS ('
					echo '    SELECT * FROM depends AS prev'
					echo '        WHERE prev.used = TRUE AND next.used IS NOT TRUE'
					echo "        AND (${typesClause}) AND prev.dependency = next.package"
					echo ');'
					echo 'SELECT changes();'  # output the number of changed rows
				} | runSQL)
			done
		'';

	in lib.mkIf (config.system.packages != null) {

		system.cleanupScripts.nodepend = lib.mkIf pkgs.stdenv.isLinux (lib.stringAfter [ "packages" ] ''
			storeHeading 'Cleaning unused system-level packages'
			flushHeading

			{
				echo 'BEGIN IMMEDIATE TRANSACTION;'
				echo 'CREATE TABLE depends ('
				echo '    package TEXT,'
				echo '    type TEXT,'
				echo '    dependency TEXT,'
				echo '    used INTEGER'
				echo ');'

				# collect all (package, dependency) pairs
				{
					dpkg-query --showformat ''\'''${Status}\t''${Package}\tpre-depends\t''${Pre-Depends}\n' --show
					dpkg-query --showformat ''\'''${Status}\t''${Package}\tdepends\t''${Depends}\n' --show
					dpkg-query --showformat ''\'''${Status}\t''${Package}\trecommends\t''${Recommends}\n' --show
				} | awk '
					BEGIN { FS = "\t" ; quote = "\047" }
					/^install ok installed/ {
						if ($4 != "") {
							split($4, depends, /, *| *\| */)
							for (i in depends) {
								sub(/ *\(.*\)/, "", depends[i])  # remove version information
								print "INSERT INTO depends (package, type, dependency) VALUES (" quote $2 quote ", " quote $3 quote ", " quote depends[i] quote ");"
							}
						} else {
							print "INSERT INTO depends (package) VALUES (" quote $2 quote ");"
						}
					}
				'

				# collect package provides and replace dependency with providing package
				dpkg-query --showformat ''\'''${Status}\t''${Package}\t''${Provides}\n' --show '*' | awk '
					BEGIN { FS = "\t" ; quote = "\047" }
					/^install ok installed/ {
						split($3, provides, /, */)
						for (i in provides) {
							sub(/ *\(.*\)/, "", provides[i])  # remove version information
							print "UPDATE depends SET dependency = " quote $2 quote " WHERE dependency = " quote provides[i] quote ";"
						}
					}
				'

				echo 'COMMIT TRANSACTION;'
			} | runSQL

			# mark packages as used starting from configured packages as roots
			# the sets of traversed dependencies must be in decreasing order
			# otherwise we may stop marking at an earlier marked package whose
			# transitive depencies are then not fully explored
			${markPackagesUsed packagesWithRecommends ["pre-depends" "depends" "recommends"]}
			${markPackagesUsed packagesWithoutRecommends ["pre-depends" "depends"]}

			{
				# output remaining unused packages
				echo 'SELECT package FROM depends WHERE used IS NOT TRUE GROUP BY package ORDER BY package;'
				echo 'DROP TABLE depends;'
			} | runSQL | sed -E '
				s/^/apt-get purge /
				/^apt-get purge (linux-image-|linux-modules-)/ s/^/#/
			' | interactiveCommands nodepend \
				'Installed system packages not needed by any package dependency.' \
				'Packages will be uninstalled unless lines are commented or removed.'
		'');
	};
}
