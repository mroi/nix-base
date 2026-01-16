{ config, lib, pkgs, ... }: {

	options.system.files = {
		used = lib.mkOption {
			type = lib.types.listOf lib.types.path;
			default = [];
			description = "List of paths (globbing patterns are supported) of files known to be in use. These paths are used to identify unused files.";
		};
		unusedAge = lib.mkOption {
			type = lib.types.int;
			default = 380;
			description = "Number of days after which a file that has not been modified or accessed is considered unused.";
		};
	};

	config = let

		# inherit the config conditions of clean-files
		condition = (import ./files.nix { inherit config lib pkgs; }).config.condition;

		usedFiles = pkgs.writeText "files-used" (lib.concatLines config.system.files.used);

		age = toString config.system.files.unusedAge;

	in {

		system.cleanupScripts.unused = lib.mkIf condition (lib.stringAfter [ "files" "unknown" ] ''
			storeHeading 'Cleaning unused files'
			requireCommands clean-files
			flushHeading

			# mark files as used
			{
				echo 'BEGIN IMMEDIATE TRANSACTION;'
				echo 'ALTER TABLE files ADD COLUMN used INTEGER DEFAULT FALSE;'
				sed "s/'/'''/g ; s/.*/UPDATE files SET used = TRUE WHERE path GLOB '&';/" ${usedFiles}
				echo 'UPDATE files SET used = TRUE WHERE source IS NOT NULL;'
				echo 'COMMIT TRANSACTION;'
			} | runSQL

			printInfo 'Checking for dangling symlinks'

			# live symlinks are considered in use
			# shellcheck disable=SC2016
			{
				echo 'SELECT path FROM files'
				echo '    WHERE used IS FALSE'
				echo '    AND type = 10'  # symlink type code
				echo ';'
			} | runSQL | \
				trace sudo sh -c 'while read -r link ; do test -e "$link" && echo "$link" ; done' > links || true
			sed "s/'/'''/g ; s/.*/UPDATE files SET used = TRUE WHERE path = '&';/" links | runSQL
			rm links

			printInfo 'Checking for empty directores'

			# non-empty directories are considered in use
			{
				echo 'UPDATE files SET used = TRUE'
				echo '    WHERE used IS FALSE'
				echo '    AND type = 4'  # directory type code
				echo '    AND links > 2'  # empty directories have link count 2 (. and ..)
				echo ';'
			} | runSQL

			now=$(date +%s)

			# empty directories that were recently modified are considered in use
			{
				echo 'UPDATE files SET used = TRUE'
				echo '    WHERE used IS FALSE'
				echo '    AND type = 4'  # directory type code
				echo "    AND mtime > $now - ${age} * 24 * 60 * 60"
				echo ';'
			} | runSQL

			printInfo 'Checking for files not being accessed'

			# we want to use the atime of regular files to determine recent access
			# but if the atime is newer (numerically larger) than the mtime, it may not be accurate
			# due to relaxed atime handling, atime is not updated if it is already newer than mtime
			# solution: backdate atime to before mtime to check for access on subsequent clean-unused
			# also bump the ctime (using touch -r) so we know when we made this atime change
			# shellcheck disable=SC2016
			{
				echo "SELECT strftime('%Y%m%d%H%M.%S', mtime - 1, 'unixepoch'), path FROM files"
				echo '    WHERE used IS FALSE'
				echo '    AND type != 10 AND type != 4'  # exclude symlinks and directories
				echo "    AND mtime <= atime AND atime <= $now - ${age} * 24 * 60 * 60"
				echo ';'
			} | runSQL | while read -r line ; do
				atime=''${line%%|*}
				file=''${line#*|}
				echo "$atime $file"
			done | trace sudo sh -c 'while read -r atime file ; do touch -a -t "$atime" "$file" && touch -r "$file" "$file" ; done' 2> /dev/null || true

			# after backdating, mark those same files as possibly in use as atime may have been wrong
			{
				echo 'UPDATE files SET used = TRUE'
				echo '    WHERE used IS FALSE'
				echo '    AND type != 10 AND type != 4'
				echo "    AND mtime <= atime AND atime <= $now - ${age} * 24 * 60 * 60"
				echo ';'
			} | runSQL

			# files recently accessed are considered in use
			{
				echo 'UPDATE files SET used = TRUE'
				echo '    WHERE used IS FALSE'
				echo '    AND type != 10 AND type != 4'
				echo "    AND (atime > $now - ${age} * 24 * 60 * 60"
				echo "        OR mtime > $now - ${age} * 24 * 60 * 60"
				echo "        OR ctime > $now - ${age} * 24 * 60 * 60"
				echo '    )'
				echo ';'
			} | runSQL

			# delete unused unrestricted files interactively
			echo 'SELECT path FROM files WHERE used IS FALSE AND restricted IS FALSE ORDER BY path;' | runSQL | \
				interactiveDeletes unused 'These files appear to be unused.'

			storeHeading -

			# delete unused restricted files in recovery
			echo 'SELECT path FROM files WHERE used IS FALSE AND restricted IS TRUE ORDER BY path;' | runSQL | \
				sed "/ / s/.*/'&'/ ; s/^/rm -rf /" | recoveryCommands

			storeHeading -
			sanitizeFileList used ${usedFiles}

			echo 'ALTER TABLE files DROP COLUMN used;' | runSQL
		'');
	};
}
