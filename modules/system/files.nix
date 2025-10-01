{ lib, pkgs, ... }: {

	config.system.cleanupScripts.files = ''
		storeHeading Collecting file information
		flushHeading

		{
			echo 'BEGIN IMMEDIATE TRANSACTION;'
			echo 'CREATE TABLE files (path TEXT PRIMARY KEY);'

			{
	'' + lib.optionalString pkgs.stdenv.isDarwin ''
				# scan data volume for firmlink in the root tree and for remaining non-firmlinked files
				firmlinks() {
					files="$(find "$1" -mindepth 1 -maxdepth 1 2> /dev/null || true)"
					forFile() {
						orig=''${1#/System/Volumes/Data}
						# shellcheck disable=SC3013
						if test "$1" -ef "$orig" ; then
							# file is firmlinked from the root tree
							roots="$roots$newline$orig"
							return
						fi
						if test -e "$orig" -o -L "$orig" && test "$(stat -f %i "$1")" = "$(stat -f %i "$orig")" ; then
							# file is firmlinked from the root tree
							roots="$roots$newline$orig"
							return
						fi
						if test -d "$1" ; then
							firmlinks "$1"
						fi
						# file is not firmlinked from the root tree
						echo "$1"
					}
					forLines "$files" forFile
				}
				firmlinks /System/Volumes/Data
				if test -r /etc/synthetic.conf ; then
					roots="$roots$newline$(sed 's/^/\//' < /etc/synthetic.conf)"
				fi
	'' + lib.optionalString pkgs.stdenv.isLinux ''
				roots=$(mount | sed -En '/^\//{s/^.* on (.*) type .*$/\1/;/(^\/media\/|^\/mnt\/)/d;p;}')
	'' + ''

				# shellcheck disable=SC2086
				trace sudo find $roots -mount 2> /dev/null

			} | tr '\n' '\0' | trace sudo xargs -0 stat ${lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
					Linux = "-c %n";
					Darwin = "-f %N";
				}} | sed -E "s/'/'''/g;s/(.*)/INSERT INTO files (path) VALUES('\1');/"

			echo 'COMMIT TRANSACTION;'

		} | runSQL
	'';
}
