{ config, lib, pkgs, ... }: {

	options.services.unison = {
		enable = lib.mkEnableOption "Unison file synchronization" // { default = true; };
		intercept = lib.mkEnableOption "Unison intercept library" // { default = true; };
		configDir = lib.mkOption {
			type = lib.types.pathWith { absolute = false; };
			default = ".unison";
			description = "Unison configuration directory relative to the user’s home.";
		};
		userAccountProfile = lib.mkOption {
			type = lib.types.nullOr lib.types.singleLineStr;
			default = null;
			description = "Unison profile which is used to sync user accounts at login.";
		};
		syncRoot = lib.mkEnableOption "root user sync with Unison" // { default = true; };
	};

	config = let

		cfg = config.services.unison;
		shared = lib.escapeShellArg config.users.sharedFolder;
		binDir = lib.escapeShellArg config.users.binDir;
		serviceDir = lib.escapeShellArg config.users.serviceDir;
		configDir = lib.escapeShellArg cfg.configDir;
		baseDir = if config.users.sharedFolder != null then shared else	"\"$HOME\"";
		stagingDir = "\"${config.users.root.stagingDirectory}\"";

		userScript = pkgs.writeScript "unison" (lib.concatLines ([
			"#!/bin/sh"
		] ++ lib.optionals pkgs.stdenv.isLinux [
			(lib.optionalString cfg.intercept "LD_PRELOAD=${baseDir}/${configDir}/libintercept.so " + (
				if baseDir == shared then
					"exec ${shared}/.local/state/nix/profile/bin/unison \"$@\""
				else
					"exec \"\${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile/bin/unison\" \"$@\""
			))
		] ++ lib.optionals pkgs.stdenv.isDarwin [
			"cd ${baseDir}/${serviceDir}/Unison.app/ || exit"
			"exec Contents/MacOS/Unison -ui text \"$@\""
		]));

		rootScript = pkgs.writeScript "unison" (lib.concatLines ([
			"#!/bin/sh"
		] ++ lib.optionals pkgs.stdenv.isLinux [
			(lib.optionalString cfg.intercept "LD_PRELOAD=~/${configDir}/libintercept.so " +
				"exec ~/.nix/profile/bin/unison \"$@\"")
		] ++ lib.optionals pkgs.stdenv.isDarwin [
			"export HOME=/private/var/root"
			"cd $HOME/${binDir}/Unison.app/ || exit"
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

		assertions = [{
			assertion = config.users.sharedFolder != null || cfg.userAccountProfile == null;
			message = "Syncing the Unison profile ${cfg.userAccountProfile} requires users.sharedFolder.";
		}];

		# install Unison
		environment.profile = lib.mkIf pkgs.stdenv.isLinux [ "nix-base#unison" ];
		environment.rootPaths = lib.mkIf pkgs.stdenv.isLinux [
			(lib.getExe (pkgs.callPackage ../../packages/unison.nix {}))
		];
		environment.bundles."${baseDir}/${serviceDir}/Unison.app" = lib.mkIf pkgs.stdenv.isDarwin {
			pkg = pkgs.callPackage ../../packages/unison.nix { inherit (cfg) intercept; };
			install = ''
				${makeSubpaths baseDir serviceDir}
				makeTree 755${lib.optionalString (baseDir == shared) "::admin"} "$out" "$pkg/Library/CoreServices/Unison.app"
				codesign -s "$(id -F)" "$out"
			'';
		};
		# FIXME: environment.bundles on macOS
		system.activationScripts.unison = lib.stringAfter [ "profile" "shared" ] (''
			storeHeading 'Installing Unison'
			${makeSubpaths baseDir binDir}
			makeFile 755 ${baseDir}/${binDir}/unison ${userScript}
		'' + lib.optionalString (pkgs.stdenv.isLinux && cfg.intercept) ''
			if ! test -x ${baseDir}/${configDir}/libintercept.so ; then
				${makeSubpaths baseDir configDir}
				makeFile 755 ${baseDir}/${configDir}/libintercept.so "${pkgs.lazyCallPackage ../../packages/unison.nix { intercept = true; }}/lib/libintercept.so"
			fi
		'' + lib.optionalString cfg.syncRoot (''
			${makeSubpaths stagingDir binDir}
			makeFile 755 ${stagingDir}/${binDir}/unison ${rootScript}
		'' + lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
			Linux = lib.optionalString cfg.intercept ''
				${makeSubpaths stagingDir configDir}
				makeLink ${stagingDir}/${configDir}/libintercept.so ${baseDir}/${configDir}/libintercept.so
			'';
			Darwin = ''
				makeLink ${stagingDir}/${binDir}/Unison.app ${baseDir}/${serviceDir}/Unison.app
			'';
		}));

		system.activationScripts.root.deps = lib.mkIf cfg.syncRoot [ "unison" ];

		# use Unison to prepare user accounts at login
		environment.loginHook.unison = lib.mkIf (cfg.userAccountProfile != null) (''
			# setup user at login
			eval export HOME=~"$USER"
			if test -d "$HOME" -a -d ${baseDir}/${configDir} -a -x ${baseDir}/${binDir}/unison ${lib.optionalString pkgs.stdenv.isLinux "-a ! -e \"$HOME/.ecryptfs\" "}; then
				cd "$HOME"
				su -m "$USER" <<- 'EOF'
					umask 0022'' + "\n"
		+ lib.optionalString pkgs.stdenv.isLinux (''
					# remove the system default files
					for file in .bash_logout .bashrc .inputrc .profile ; do
						size=$(stat -c %s /etc/skel/$file)
						cmp -s -n "$size" $file /etc/skel/$file && rm $file
					done'' + "\n")
		+ ''
					# minimal Unison setup
					if ! test -d ${configDir} ; then
						mkdir -m 0700 ${configDir}
					fi
					symlinkRecursive() {
						if test -f ${configDir}/"$1" ; then return ; fi
						if test -f ${baseDir}/${configDir}/"$1" ; then
							ln -s ${baseDir}/${configDir}/"$1" ${configDir}/
							# symlink all includes within this file
							sed -n '/^include /{s/^include //;p;}' ${configDir}/"$1" | while read -r include ; do
								symlinkRecursive "$include"
							done
						elif test "$1" = common.root ; then
							echo "root = $HOME/" > ${configDir}/common.root
						else
							touch ${configDir}/"$1"
						fi
					}
					symlinkRecursive ${lib.escapeShellArg cfg.userAccountProfile}
					# run Unison to initialize user account
					HOME="$HOME" ${baseDir}/${binDir}/unison -ui text -silent \
						-nodeletionpartial "BelowPath * -> $HOME/" \
						-nodeletionpartial "BelowPath .* -> $HOME/" \
						-noupdatepartial "BelowPath * -> $HOME/" \
						-noupdatepartial "BelowPath .* -> $HOME/" \
						${lib.escapeShellArg cfg.userAccountProfile} > /dev/null 2>&1'' + "\n"
		+ lib.optionalString config.services.openssh.enable (''
					# special case: .ssh
					if ! test -d .ssh ; then
						mkdir -m 0700 .ssh
						touch .ssh/authorized_keys .ssh/known_hosts
						chmod 600 .ssh/known_hosts
					fi'' + "\n")
		+ ''
				EOF
			fi
		'');

		# sync the root account using Unison
		users.root.syncCommand = lib.mkIf cfg.syncRoot (toString (pkgs.writeScript "unison-root" (''#!/bin/sh -e
			if ! test -x ~root/${binDir}/unison ; then
				echo 'Installing Unison executable for the root user' >&2
				mkdir -p ~root/${binDir}
				cp ${rootScript} ~root/${binDir}/unison
		'' + lib.optionalString pkgs.stdenv.isLinux ''
				mkdir -p ~root/.nix/profile/bin
				ln -s ${lib.getExe (pkgs.callPackage ../../packages/unison.nix {})} ~root/.nix/profile/bin/
		'' + lib.optionalString pkgs.stdenv.isDarwin ''
				cp ${baseDir}/${serviceDir}/Unison.app ~root/${binDir}/
		'' + lib.optionalString (pkgs.stdenv.isLinux && cfg.intercept) ''
				mkdir -p ~root/${configDir}
				cp ${baseDir}/${configDir}/libintercept.so ~root/${configDir}/
		'' + ''
			fi
			if ! test -r ~root/${configDir}/default.prf ; then
				echo 'Installing default Unison profile for the root user' >&2
				mkdir -p ~root/${configDir}
				cat > ~root/${configDir}/default.prf <<- EOF
					root = $(eval echo ~root/)
					root = $(eval HOME=~"$SUDO_USER" ; eval echo ${stagingDir})
					force = $(eval HOME=~"$SUDO_USER" ; eval echo ${stagingDir})
					times = true
					log = false
					${
						lib.optionalString pkgs.stdenv.isDarwin "\nfollow    = Name Unison.app" +
						lib.optionalString (pkgs.stdenv.isLinux && cfg.intercept) "\nfollow    = Name libintercept.so"
					}
					ignore    = Path .*
					ignorenot = Path .nix
					ignorenot = Path ${lib.head (lib.splitString "/" configDir)}
					ignore    = Path ${configDir}/ar*
					ignore    = Path ${configDir}/fp*
					ignore    = Path ${configDir}/lk*
					ignorenot = Path ${lib.head (lib.splitString "/" binDir)}'' + "\n"
		+ lib.optionalString pkgs.stdenv.isDarwin ''
					ignore    = Path Library/*
					ignore    = Path Library/.*
					ignorenot = Path Library/Preferences
					ignore    = Path Library/Preferences/*
					ignore    = Path Library/Preferences/.*
					ignorenot = Path Library/Preferences/com.apple.loginwindow.plist
		'' + ''
				EOF
			fi

			if test -t 0 ; then
				exec ~root/${binDir}/unison "$@" || true
			else
				exec ~root/${binDir}/unison "$@" -batch -terse
			fi
		'')));
	};
}
