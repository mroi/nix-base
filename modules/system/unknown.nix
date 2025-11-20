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

			# delete unknown unrestricted files interactively
			echo 'SELECT path FROM files WHERE known IS FALSE AND restricted IS FALSE ORDER BY path;' | runSQL | \
				interactiveDeletes unknown 'These files are not known to be present on ${lib.replaceString "generic" "Linux" config.system.distribution}.'

			storeHeading -

			# delete unknown restricted files in recovery
			echo 'SELECT path FROM files WHERE known IS FALSE AND restricted IS TRUE ORDER BY path;' | runSQL | \
				sed "/ / s/.*/'&'/ ; s/^/rm -rf /" | recoveryCommands

			storeHeading -
			sanitizeFileList known ${knownFiles}

			echo 'ALTER TABLE files DROP COLUMN known;' | runSQL
		'';
	};
}
