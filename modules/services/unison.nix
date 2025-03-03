{ config, lib, ... }: {

	options.services.unison = {
		enable = lib.mkEnableOption "Unison file synchronization" // { default = true; };
		configDir = lib.mkOption {
			type = lib.types.singleLineStr;
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
		shared = config.environment.shared;
		localConfigDir = lib.escapeShellArg "${cfg.configDir}";
		sharedConfigDir = lib.escapeShellArg "${shared.folder}/${cfg.configDir}";

	in lib.mkIf cfg.enable {

		assertions = [{
			assertion = shared.folder != null || cfg.userAccountProfile == null;
			message = "Syncing the Unison profile ${cfg.userAccountProfile} requires environment.shared.enable.";
		}];

		environment.loginHook.unison = lib.mkIf (cfg.userAccountProfile != null) (''
			# setup user at login
			eval HOME=~"$1"
			if test -d "$HOME" ; then
				su -m "$1" <<- 'EOF'
					cd "$HOME"
					umask 0022
					# minimal Unison setup
					if ! test -d ${localConfigDir} ; then
						mkdir -m 0700 ${localConfigDir}
					fi
					symlinkRecursive() {
						if test -f ${localConfigDir}/"$1" ; then return ; fi
						if test -f ${sharedConfigDir}/"$1" ; then
							ln -s ${sharedConfigDir}/"$1" ${localConfigDir}/
							# symlink all includes within this file
							sed -n '/^include /{s/^include //;p;}' ${localConfigDir}/"$1" | while read -r include ; do
								symlinkRecursive "$include"
							done
						elif test "$1" = common.root ; then
							echo "root = $HOME/" > ${localConfigDir}/common.root
						else
							touch ${localConfigDir}/"$1"
						fi
					}
					symlinkRecursive ${lib.escapeShellArg cfg.userAccountProfile}
					# run Unison to initialize user account
					HOME="$HOME" ${lib.escapeShellArg "${shared.exeDir}/unison"} -ui text -batch -silent \
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
	};
}
