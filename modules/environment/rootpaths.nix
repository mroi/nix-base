{ config, lib, pkgs, ... }: {

	options.environment.rootPaths = lib.mkOption {
		type = lib.types.listOf lib.types.pathInStore;
		default = [];
		example = "[ (lib.getExe pkgs.nix) ]";
		description = "Files to be installed in the Nix profile of the root user.";
	};

	config = let

		# list of all subpaths after the store directory
		# for /nix/store/<hash>-<name>/a/b/c this is [ "" "a" "a/b" "a/b/c" ]
		subpaths = path: lib.pipe path [
			(lib.removePrefix builtins.storeDir)
			(lib.splitString "/")
			(lib.drop 2)
			(lib.foldl (list: element: list ++ [ "${lib.last list}/${element}" ]) [ "" ])
			(map (lib.removePrefix "/"))
		];

		relativeDirectories = path: lib.dropEnd 1 (subpaths path);
		relativePath = path: lib.last (subpaths path);
		profilePath = path: "${config.users.root.stagingDirectory}/.nix/profile/${relativePath path}";

		addPathScript = path: (lib.concatLines (map (dir: ''
			makeDir 755 "${config.users.root.stagingDirectory}/.nix/profile/${dir}"
		'') (relativeDirectories path))) + (file: ''
			makeLink 755 "${path}" "${config.users.root.stagingDirectory}/.nix/profile/${file}"
		'') (relativePath path);

	in lib.mkIf (config.environment.rootPaths != []) {

		system.activationScripts.rootpaths = lib.stringAfter [ "nix" "staging" ] ''
			storeHeading 'Updating Nix profile paths for the root user'

			# add all requested paths
			makeDir 700 "${config.users.root.stagingDirectory}/.nix"
			${lib.concatLines (map addPathScript config.environment.rootPaths)}

			# remove any superfluous paths
			paths="${lib.concatLines (map profilePath config.environment.rootPaths)}"
			find "${config.users.root.stagingDirectory}/.nix/profile" -type l | while read -r file ; do
				if ! hasLine "$paths" "$file" ; then
					trace rm "$file"
					trace rmdir -p "''${file%/*}" || true
				fi
			done

			# prevent the root profile from being garbage collected
			makeLink 755:root:nix ~root/.nix/profile /nix/var/nix/gcroots/per-user/root/profile
		'';

		system.activationScripts.root.deps = [ "rootpaths" ];
	};
}
