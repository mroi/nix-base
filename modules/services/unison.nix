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

		unison = pkgs.callPackage ../../packages/unison.nix {};
		unison-intercept = pkgs.callPackage ../../packages/unison.nix { intercept = true; };

		cfg = config.services.unison;
		shared = lib.escapeShellArg config.users.shared.folder;
		binDir = lib.escapeShellArg config.users.binDir;
		stateDir = lib.escapeShellArg config.users.stateDir;
		serviceDir = lib.escapeShellArg config.users.serviceDir;
		configDir = lib.escapeShellArg cfg.configDir;
		baseDir = if config.users.shared.folder != null then shared else "\"$HOME\"";
		stagingDir = "\"${config.users.root.stagingDirectory}\"";

		userScript = pkgs.writeScript "unison" (lib.concatLines ([
			"#!/bin/sh"
		] ++ lib.optionals pkgs.stdenv.isLinux [
			(lib.optionalString cfg.intercept "LD_PRELOAD=${baseDir}/${configDir}/libintercept.so " + (
				if baseDir == shared then
					"exec ${shared}/${stateDir}/nix/profile/bin/unison \"$@\""
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

		# the first directory within `base` (assuming it is a user home) is created with
		# 700 permissions, unless `base` is the shared folder
		makeHomeDir = base: path: let
			firstPerms = if base == shared then "755::${config.users.shared.group}" else "700";
			firstDir = lib.head (lib.splitString "/" path);
		in ''
			makeDir ${firstPerms} ${base}/${firstDir}
		'' + lib.optionalString (path != firstDir) ''
			makeDir 755 ${base}/${path}
		'';

	in lib.mkIf cfg.enable {

		assertions = [{
			assertion = config.users.shared.folder != null || cfg.userAccountProfile == null;
			message = "Syncing the Unison profile ${cfg.userAccountProfile} requires users.shared.folder";
		}];

		system.build.packages = { inherit unison-intercept; };

		# install Unison
		environment.profile = lib.mkIf pkgs.stdenv.isLinux [ "nix-base#unison" ];
		environment.rootPaths = lib.mkIf pkgs.stdenv.isLinux [ (lib.getExe unison) ];
		environment.bundles = lib.mkIf (pkgs.stdenv.isDarwin && baseDir == shared) {
			"${shared}/${serviceDir}/Unison.app" = {
				pkg = if cfg.intercept then unison-intercept else unison;
				install = ''
					makeDir 755::admin "$(dirname "$out")"
					makeTree 755::admin "$out" "$pkg/Library/CoreServices/Unison.app"
				'';
			};
		};

		system.activationScripts.unison = lib.stringAfter [ "profile" "shared" ] (''
			storeHeading 'Installing Unison'
			${makeHomeDir baseDir binDir}
			makeFile 755 ${baseDir}/${binDir}/unison ${userScript}
		'' + lib.optionalString (pkgs.stdenv.isLinux && cfg.intercept) ''
			if ! test -x ${baseDir}/${configDir}/libintercept.so ; then
				${makeHomeDir baseDir configDir}
				makeFile 755 ${baseDir}/${configDir}/libintercept.so "${pkgs.lazyCallPackage ../../packages/unison.nix { intercept = true; }}/lib/libintercept.so"
			fi
		'' + lib.optionalString cfg.syncRoot (''
			${makeHomeDir stagingDir binDir}
			makeFile 755 ${stagingDir}/${binDir}/unison ${rootScript}
			${makeHomeDir stagingDir configDir}
		'' + lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
			Linux = lib.optionalString cfg.intercept ''
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
						chmod 600 .ssh/authorized_keys .ssh/known_hosts
					fi'' + "\n")
		+ ''
				EOF
			fi
		'');

		# sync the root account using Unison
		users.root.stagingDirectory = lib.mkIf cfg.syncRoot
			"$HOME/${cfg.configDir}/root-${lib.toLower pkgs.stdenv.hostPlatform.uname.system}";
		users.root.syncCommand = lib.mkIf cfg.syncRoot (toString (pkgs.writeScript "unison-root" (''#!/bin/sh -e
			if ! test -x ~root/${binDir}/unison ; then
				echo 'Installing Unison executable for the root user' >&2
				mkdir -p ~root/${binDir}
				cp ${rootScript} ~root/${binDir}/unison
		'' + lib.optionalString pkgs.stdenv.isLinux ''
				mkdir -p ~root/.nix/profile/bin
				ln -s ${lib.getExe unison} ~root/.nix/profile/bin/
		'' + lib.optionalString pkgs.stdenv.isDarwin ''
				cp -R ${baseDir}/${serviceDir}/Unison.app ~root/${binDir}/
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
