{ config, lib, pkgs, ... }: {

	options.system.files.known = lib.mkOption {
		type = lib.types.listOf lib.types.path;
		default = [];
		description = "List of paths (globbing patterns are supported) of files known to exist. These known paths are used to identify leftover files.";
	};

	config = let

		# inherit the config conditions of clean-files
		condition = (import ./files.nix { inherit config lib pkgs; }).config.condition;

		knownFiles = pkgs.writeText "files-known" (lib.concatLines config.system.files.known);

		# files configured as known, but where it is OK if they do not exist
		notExistOk = pkgs.writeText "files-notexist" (lib.concatLines (lib.optionals pkgs.stdenv.isLinux [
			"/nonexistent"
			"/nonexistent/*"
		] ++ lib.optionals pkgs.stdenv.isDarwin [
			"/Users/Guest"
			"/Users/Guest/*"
			"/Volumes/*"
			"/private/var/vm/sleepimage"
			"/var/empty"
			"/var/empty/*"
		]));

	in lib.mkIf condition {

		system.cleanupScripts.unknown = lib.stringAfter [ "files" ] ''
			storeHeading 'Cleaning unknown files'
			requireCommands clean-files
			flushHeading

			# mark files as known
			{
				echo 'BEGIN IMMEDIATE TRANSACTION;'
				echo 'ALTER TABLE files ADD COLUMN known INTEGER DEFAULT FALSE;'
				find "$(pwd -P)" | sed "s/.*/UPDATE files SET known = TRUE WHERE path = '&';/"  # tempdir is known
				sed "s/'/'''/g ; s/.*/UPDATE files SET known = TRUE WHERE path GLOB '&';/" ${knownFiles}
				echo 'UPDATE files SET known = TRUE WHERE source IS NOT NULL;'
				echo 'COMMIT TRANSACTION;'
			} | runSQL

			# delete unknown restricted files in recovery
			echo 'SELECT path FROM files WHERE known IS FALSE AND restricted IS TRUE ORDER BY path;' | runSQL | \
				sed "/ / s/.*/'&'/ ; s/^/rm -rf /" | recoveryCommands
			# delete unrestricted files interactively
			echo 'SELECT path FROM files WHERE known IS FALSE AND restricted IS FALSE ORDER BY path;' | runSQL | \
				interactiveDeletes unknown 'These files are not known to be present on ${lib.replaceString "generic" "Linux" config.system.distribution}.'

			sanitizeFileList() {
				# warn about files being listed multiple times
				case "$1" in
					known) cat ${knownFiles} ;;
				esac | sort | uniq -d | if read -r first ; then
					printWarning "Files listed as $1 multiple times:"
					echo "$first" >&2
					cat >&2
				fi
				# warn about files being listed that do not exist
				case "$1" in
					known) cat ${knownFiles} ;;
				esac | sort | sed "s/'/'''/g ; s/.*/SELECT '&' WHERE NOT EXISTS (SELECT * FROM files WHERE path GLOB '&');/" | \
					runSQL | grep -Fvx --file=${notExistOk} | if read -r first ; then
						printWarning "Files listed as $1 do not exist:"
						echo "$first" >&2
						cat >&2
					fi
			}
			sanitizeFileList known
		'';
	};
}
