{ config, lib, pkgs, ... }: {

	options.system.files.used = lib.mkOption {
		type = lib.types.listOf lib.types.path;
		default = [];
		description = "List of paths (globbing patterns are supported) of files known to be in use. These paths are used to identify unused files.";
	};

	config = let

		# inherit the config conditions of clean-files
		condition = (import ./files.nix { inherit config lib pkgs; }).config.condition;

		usedFiles = pkgs.writeText "files-used" (lib.concatLines config.system.files.used);

	in lib.mkIf condition {

		system.cleanupScripts.unused = lib.stringAfter [ "files" "unknown" ] ''
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

			# empty directories modified in the last 360 days are considered in use
			{
				echo 'UPDATE files SET used = TRUE'
				echo '    WHERE used IS FALSE'
				echo '    AND type = 4'  # directory type code
				echo "    AND mtime > $now - 360 * 24 * 60 * 60"
				echo ';'
			} | runSQL

			printInfo 'Checking for files not being accessed'

			# files accessed within the last 360 days are considered in use
			# but if the atime is newer (numerically larger) than the mtime, it may not be accurate
			# due to relaxed atime handling, atime is not updated if it is newer than mtime
			# solution: backdate atime to before mtime so we can check again on the next clean-unused run
			# shellcheck disable=SC2016
			{
				echo "SELECT strftime('%Y%m%d%H%M.%S', mtime - 1, 'unixepoch'), path FROM files"
				echo '    WHERE used IS FALSE'
				echo '    AND type != 10 AND type != 4'  # exclude symlinks and directories
				echo "    AND mtime <= atime AND atime <= $now - 360 * 24 * 60 * 60"
				echo ';'
			} | runSQL | while read -r line ; do
				atime=''${line%%|*}
				file=''${line#*|}
				echo "$atime $file"
			done | trace sudo sh -c 'while read -r atime file ; do touch -a -t "$atime" "$file" ; done' 2> /dev/null || true

			# after backdating atime, mark those same files as possibly in use as atime may have been wrong
			{
				echo 'UPDATE files SET used = TRUE'
				echo '    WHERE used IS FALSE'
				echo '    AND type != 10 AND type != 4'
				echo "    AND mtime <= atime AND atime <= $now - 360 * 24 * 60 * 60"
				echo ';'
			} | runSQL

			# files accessed within the last 360 days are considered in use
			{
				echo 'UPDATE files SET used = TRUE'
				echo '    WHERE used IS FALSE'
				echo '    AND type != 10 AND type != 4'
				echo "    AND (atime > $now - 360 * 24 * 60 * 60"
				echo "        OR mtime > $now - 360 * 24 * 60 * 60"
				echo '    )'
				echo ';'
			} | runSQL

			# TODO: process file atomicity (like SQLite databases: *, *-shm, *-wal — one used, all used)
			# add 'stem' column
			# dump rowids and paths to file, process by sed script derived from atomicity patterns
			# create sed script file from system.files.connections:
			#   s|^([0-9]+)\|<pattern>$|UPDATE … SET stem = '\2' WHERE rowid = \1;|
			# process:
			#  { echo TRANSACTION BEGIN ; sed -f … ; echo TRANSACTION END ; } | runSQL
			# ‘stem’ column can then be used to max-aggregate ‘used’ column

			# TODO: directories with only unused files are unused themselves? iterate like nodepend?

			# delete unused unrestricted files interactively
			echo 'SELECT path FROM files WHERE used IS FALSE AND restricted IS FALSE ORDER BY path;' | runSQL | \
				interactiveDeletes unused 'These files appear to be unused.'

			storeHeading -

			# delete unused restricted files in recovery
			echo 'SELECT path FROM files WHERE used IS FALSE AND restricted IS TRUE ORDER BY path;' | runSQL | \
				sed "/ / s/.*/'&'/ ; s/^/rm -rf /" | recoveryCommands

			storeHeading -

			sanitizeFileList used ${usedFiles}
		'';
	};
}
