{ config, lib, pkgs, ... }: {

	options.system.files.used = lib.mkOption {
		type = lib.types.listOf lib.types.path;
		default = [];
		description = "List of paths (globbing patterns are supported) of files known to be in use. These paths are used to identify unused files.";
	};

	config = let

		# inherit the config conditions of clean-files
		condition = (import ./files.nix { inherit config lib pkgs; }).config.condition;

	in lib.mkIf condition {

		system.cleanupScripts.unused = lib.stringAfter [ "files" "unknown" ] ''
			storeHeading 'Cleaning unused files'
			requireCommands clean-files clean-unknown

			# TODO: for files that are known, but not used: execute usage checks
			# TODO: mark for deletion if a) dead link, b) empty directory, c) access time >360 days
			# TODO: for c) update access time to be after modification time

			# TODO: process file atomicity (like SQLite databases: *, *-shm, *-wal — one known, all known)
			# TODO: add 'stem' column by copying path and removing known suffixes
			# TODO 'stem' column can then be used to max-aggregate known and used

			# TODO: interactive deletion, split off files that must be deleted in recovery

			sanitizeFileList used
		'';
	};
}
