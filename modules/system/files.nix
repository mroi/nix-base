{ config, lib, pkgs, ... }: {

	config = let

		enable = config.system.packages != null || config.environment.bundles != {} ||
			(config.environment.apps != null && (config.environment.flatpak == "system" || pkgs.stdenv.isDarwin));

	in lib.mkIf enable {

		system.cleanupScripts.files = lib.stringAfter [ "volumes" ] (''
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
						# shellcheck disable=SC2329
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
					roots=$(mount | sed -En '/^\// { s/^.* on (.*) type .*$/\1/ ; /(^\/media\/|^\/mnt\/)/d ; p ; }')
		'' + ''

					# shellcheck disable=SC2086
					trace sudo find $roots -mount ! \( -path /nix/store -prune \) 2> /dev/null

				} | tr '\n' '\0' | {
					# override checkArgs in subshell so interactive runs won’t prompt twice within this pipe
					checkArgs() { return 1 ; }
					trace sudo xargs -0 stat ${lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
						Linux = "-c %n";
						Darwin = "-f %N";
					}}
				} | sed "s/'/'''/g ; s/.*/INSERT OR IGNORE INTO files (path) VALUES ('&');/"

				echo 'COMMIT TRANSACTION;'

			} | runSQL
		'');
	};
}
