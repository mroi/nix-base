{ config, lib, pkgs, ... }: {

	config = let

		enable = config.system.packages != null || config.environment.bundles != {} ||
			(config.environment.apps != null && (config.environment.flatpak == "system" || pkgs.stdenv.isDarwin));

		# files implicitly (i.e. not by file flags) protected from being modified
		sipProtectedFiles = pkgs.writeText "files-protected" (lib.concatLines [
			"/Library/SystemExtensions/.staging"
			"/Library/SystemMigration/History/*"
		]);

	in lib.mkIf enable {

		system.cleanupScripts.files = lib.stringAfter [ "volumes" ] (''
			storeHeading Collecting file information
			flushHeading

			{
				echo 'CREATE TABLE sources ('
				echo '    source INTEGER PRIMARY KEY,'
				echo '    system TEXT,'
				echo '    name TEXT'
				echo ');'
				echo 'CREATE TABLE files ('
				echo '    path TEXT PRIMARY KEY,'
				echo '    protected INTEGER,'
				echo '    source INTEGER,'
				echo '    FOREIGN KEY (source) REFERENCES sources (id)'
				echo ');'

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
						Linux = "-c '- %n'";
						Darwin = "-f '%Sf %N'";
					}}
				} | awk '{
					# extract metadata columns
					flags = $1
					if (flags ~ /restricted/ || flags ~ /sunlnk/) protected = "TRUE" ; else protected = "FALSE"
					# remove extracted leading columns
					sub(/^[^ ]+ /, "")
					# SQL-escape single quotation marks
					quote = "\047"
					gsub(quote, quote quote)
					path = $0
					# print SQL statement
					print "INSERT OR IGNORE INTO files (path, protected) VALUES (" quote path quote ", " protected ");"
				}'

		'' + lib.optionalString pkgs.stdenv.isDarwin ''
				sed "s/'/'''/g ; s/.*/UPDATE files SET protected = TRUE WHERE path GLOB '&';/" ${sipProtectedFiles}
		'' + ''

			} | runSQL

			# other NixOS modules will amend this cleanup script by marking files with install sources
			# usage: <command listing files> | addSource <package system> <package name> <SQL WHERE clause>
			addSource() {
				echo "INSERT OR IGNORE INTO sources (system, name) VALUES ('$1', '$2');"
				sed "s/'/'''/g ; s|.*|UPDATE files SET source = (SELECT source FROM sources WHERE system = '$1' AND name = '$2') $3;|"
			}

			# other NixOS modules will evaluate lists of known/used files which we want to check
			# usage: sanitizeFileList <list type> <list file>
			sanitizeFileList() {
				# warn about files being listed multiple times
				cat "$2" | sort | uniq -d | if read -r first ; then
					printWarning "Files listed as $1 multiple times:"
					echo "$first" >&2
					cat >&2
				fi
				# warn about files being listed that do not exist
				cat "$2" | sort | sed "s/'/'''/g ; s/.*/SELECT '&' WHERE NOT EXISTS (SELECT * FROM files WHERE path GLOB '&');/" | \
					runSQL | if read -r first ; then
						printWarning "Files listed as $1 do not exist:"
						echo "$first" >&2
						cat >&2
					fi
			}
		'');
	};
}
