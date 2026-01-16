{ config, lib, pkgs, ... }: {

	options.environment.rootPaths = lib.mkOption {
		type = lib.types.listOf lib.types.pathInStore;
		default = [];
		example = lib.literalExpression "[ (lib.getExe pkgs.nix) ]";
		description = "Files to be installed in the Nix profile of the root user.";
	};

	config = let

		# part of the path relative to the package root in the Nix store
		# for /nix/store/<hash>-<name>/a/b/c this is "a/b/c"
		relativePath = path: lib.pipe path [
			(lib.removePrefix builtins.storeDir)
			(lib.splitString "/")
			(lib.drop 2)
			(lib.concatStringsSep "/")
		];

		profilePath = path: "${config.users.root.stagingDirectory}/.nix/profile/${relativePath path}";

		addPathScript = path: ''
			makeDir 755 "${builtins.dirOf (profilePath path)}"
			makeLink 755 "${profilePath path}" "${path}"
		'';

	in lib.mkIf (config.users.root.stagingDirectory != null && config.environment.rootPaths != []) {

		system.activationScripts.rootpaths = lib.stringAfter [ "nix" "staging" ] ''
			storeHeading 'Updating Nix profile paths for the root user'

			requireCommands activate-staging activate-root

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
			makeLink 755:root:nix /nix/var/nix/gcroots/per-user/root/profile ~root/.nix/profile
		'';

		system.activationScripts.root.deps = [ "rootpaths" ];

		system.files.known = [
			"${config.users.root.home}/.nix"
			"${config.users.root.home}/.nix/profile"
			"${config.users.root.home}/.nix/profile/*"
		];
	};
}
