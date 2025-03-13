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
	};

	config = let

		cfg = config.services.unison;
		shared = lib.escapeShellArg config.users.shared.folder;
		binDir = lib.escapeShellArg config.users.binDir;
		stateDir = lib.escapeShellArg config.users.stateDir;
		serviceDir = lib.escapeShellArg config.users.serviceDir;
		configDir = lib.escapeShellArg cfg.configDir;
		baseDir = if config.users.shared.folder != null then shared else "\"$HOME\"";

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
			message = "Syncing the Unison profile ${cfg.userAccountProfile} requires users.shared.folder.";
		}];

		# install Unison
		environment.profile = lib.mkIf pkgs.stdenv.isLinux [ "nix-base#unison" ];
		environment.rootPaths = lib.mkIf pkgs.stdenv.isLinux [
			(lib.getExe (pkgs.callPackage ../../packages/unison.nix {}))
		];
		environment.bundles = lib.mkIf (pkgs.stdenv.isDarwin && baseDir == shared) {
			"${shared}/${serviceDir}/Unison.app" = {
				pkg = pkgs.callPackage ../../packages/unison.nix { inherit (cfg) intercept; };
				install = ''
					makeDir 755::admin "$(dirname "$out")"
					makeTree 755::admin "$out" "$pkg/Library/CoreServices/Unison.app"
				'';
			};
		};

		system.activationScripts.unison = lib.stringAfter [ "profile" "shared" ] ''
			storeHeading 'Installing Unison'
			${makeHomeDir baseDir binDir}
			makeFile 755 ${baseDir}/${binDir}/unison ${userScript}
		'' + lib.optionalString (pkgs.stdenv.isLinux && cfg.intercept) ''
			if ! test -x ${baseDir}/${configDir}/libintercept.so ; then
				${makeHomeDir baseDir configDir}
				makeFile 755 ${baseDir}/${configDir}/libintercept.so "${pkgs.lazyCallPackage ../../packages/unison.nix { intercept = true; }}/lib/libintercept.so"
			fi
		'';

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
	};
}
