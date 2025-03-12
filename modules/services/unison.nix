{ config, lib, pkgs, ... }: {

	options.services.unison = {
		enable = lib.mkEnableOption "Unison file synchronization" // { default = true; };
		configDir = lib.mkOption {
			type = lib.types.pathWith { absolute = false; };
			default = ".unison";
			description = "Unison configuration directory relative to the user’s home.";
		};
	};

	config = let

		cfg = config.services.unison;
		shared = lib.escapeShellArg config.users.sharedFolder;
		binDir = lib.escapeShellArg config.users.binDir;
		serviceDir = lib.escapeShellArg config.users.serviceDir;
		baseDir = if config.users.sharedFolder != null then shared else	"\"$HOME\"";

		userScript = pkgs.writeScript "unison" (lib.concatLines ([
			"#!/bin/sh"
		] ++ lib.optionals pkgs.stdenv.isLinux [
			if baseDir == shared then
				"exec ${shared}/.local/state/nix/profile/bin/unison \"$@\""
			else
				"exec \"\${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile/bin/unison\" \"$@\""
		] ++ lib.optionals pkgs.stdenv.isDarwin [
			"cd ${baseDir}/${serviceDir}/Unison.app/ || exit"
			"exec Contents/MacOS/Unison -ui text \"$@\""
		]));

		# create all subpaths of a path
		# for .local/bin this creates ${base}/.local, ${base}/.local/bin
		# the first directory is created with 700 permissions unless it is in the shared folder
		# all subsequent subpaths are created 755
		makeSubpaths = base: path: let
			sharedGroup = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = "sudo";
				Darwin = "admin";
			};
			topLevelPerms = if base == shared then "755::${sharedGroup}" else "700";
		in lib.pipe path [
			(lib.splitString "/")
			(lib.foldl (list: element: list ++ [ "${lib.last list}/${element}" ]) [ "" ])
			(lib.drop 1)
			(map (lib.removePrefix "/"))
			(x: [ "makeDir ${topLevelPerms} ${base}/${lib.head x}" ] ++ lib.tail x)
			(x: [ (lib.head x) ] ++ map (path: "makeDir 755 ${base}/${path}") (lib.tail x))
			lib.concatLines
		];

	in lib.mkIf cfg.enable {

		# install Unison
		environment.profile = lib.mkIf pkgs.stdenv.isLinux [ "nix-base#unison" ];
		environment.rootPaths = lib.mkIf pkgs.stdenv.isLinux [
			(lib.getExe (pkgs.callPackage ../../packages/unison.nix {}))
		];
		environment.bundles."${baseDir}/${serviceDir}/Unison.app" = lib.mkIf pkgs.stdenv.isDarwin {
			pkg = pkgs.callPackage ../../packages/unison.nix {};
			install = ''
				${makeSubpaths baseDir serviceDir}
				makeTree 755${lib.optionalString (baseDir == shared) "::admin"} "$out" "$pkg/Library/CoreServices/Unison.app"
				codesign -s "$(id -F)" "$out"
			'';
		};
		# FIXME: environment.bundles on macOS
		system.activationScripts.unison = lib.stringAfter [ "profile" "shared" ] ''
			storeHeading 'Installing Unison'
			${makeSubpaths baseDir binDir}
			makeFile 755 ${baseDir}/${binDir}/unison ${userScript}
		'';
	};
}
