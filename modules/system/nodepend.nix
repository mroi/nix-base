{ config, lib, pkgs, ... }: {

	config.system.cleanupScripts.nodepend = lib.mkIf (config.system.packages != null) (lib.stringAfter [ "packages" ] ''
		storeHeading 'Scanning for unused packages'
		flushHeading

		{
			echo 'BEGIN IMMEDIATE TRANSACTION;'
			echo 'CREATE TABLE depends ('
			echo '    package TEXT,'
			echo '    dependency TEXT,'
			echo '    used INTEGER'
			echo ');'

			# collect all (package, dependency) pairs
			dpkg-query --showformat ''\'''${Status}\t''${Package}\t''${Depends}\n' --show '*' | awk '
				BEGIN { FS = "\t" ; quote = "\047" }
				/^install ok installed/ {
					split($3, depends, ", *| *\| *")
					for (i in depends) {
						sub(/ *\(.*\)/, "", depends[i])  # remove version information
						print "INSERT INTO depends (package, dependency) VALUES (" quote $2 quote ", " quote depends[i] quote ");"
					}
				}
			'

			# collect package provides and replace dependency with providing package
			dpkg-query --showformat ''\'''${Status}\t''${Package}\t''${Provides}\n' --show '*' | awk '
				BEGIN { FS = "\t" ; quote = "\047" }
				/^install ok installed/ {
					split($3, provides, ", *")
					for (i in provides) {
						sub(/ *\(.*\)/, "", provides[i])  # remove version information
						print "UPDATE depends SET dependency = " quote $2 quote " WHERE dependency = " quote provides[i] quote ";"
					}
				}
			'

			# mark configured packages as used
			${lib.pipe config.system.packages [
				(map (x: "echo \"UPDATE depends SET used = 1 WHERE package = '${x}';\""))
				lib.concatLines
			]}

			echo 'COMMIT TRANSACTION;'
		} | runSQL

		# iteratively mark dependencies of used packages as used
		changes=1
		while test "$changes" -gt 0 ; do
			changes=$({
				echo 'UPDATE depends AS next SET used = 1 WHERE EXISTS ('
				echo '    SELECT * FROM depends AS prev WHERE prev.used = 1 AND prev.dependency = next.package'
				echo ');'
				echo 'SELECT changes();'  # output the number of changed rows
			} | runSQL)
		done

		{
			# output remaining unused packages
			echo 'SELECT package FROM depends WHERE used IS NULL;'
			echo 'DROP TABLE depends;'
		} | runSQL
	'');
}
