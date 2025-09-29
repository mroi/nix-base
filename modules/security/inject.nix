{ config, lib, pkgs, ... }: {

	options.security = {

		checkInjection = lib.mkEnableOption "checking for unwanted code injection";
		checkExecution = lib.mkEnableOption "checking for unwanted code execution";
	};

	config = {

		security.checkInjection = lib.mkDefault pkgs.stdenv.isDarwin;
		security.checkExecution = lib.mkDefault pkgs.stdenv.isDarwin;

		assertions = [{
			assertion = ! config.security.checkInjection || pkgs.stdenv.isDarwin;
			message = "security.checkInjection is only available on Darwin";
		} {
			assertion = ! config.security.checkExecution || pkgs.stdenv.isDarwin;
			message = "security.checkExecution is only available on Darwin";
		}];

		system.activationScripts.sip = ''
			storeHeading -

		'' + lib.optionalString config.security.checkInjection ''
			while read -r dir ; do
				plugins=$(find "$dir" -mindepth 1 -maxdepth 1 ! -name .localized 2> /dev/null || true)
				if test "$plugins" ; then
					printWarning 'Code injection point detected in plugin directory'
					printInfo "$plugins"
				fi
			done <<- EOF
				$HOME/Library/Address Book Plug-Ins
				$HOME/Library/Input Methods
				$HOME/Library/Internet Plug-Ins
				$HOME/Library/PreferencePanes
				$HOME/Library/iTunes/iTunes Plug-ins
			EOF
		'' + lib.optionalString config.security.checkExecution ''
			# check preferences governing code execution
			while read -r domain key ; do
				if defaults read "$domain" "$key" > /dev/null 2>&1 ; then
					printWarning 'Code execution point detected in preferences'
					printInfo "$domain/$key"
				fi
			done <<- EOF
				com.apple.FolderActions folderActions
				com.apple.scheduler AbsoluteSchedule
			EOF
			# check login items
			loginitems=/var/db/com.apple.xpc.launchd/loginitems.$(id -u).plist
			if test -f "$loginitems" ; then
				printWarning 'Code execution point detected in login items'
				printInfo "$loginitems"
			fi
			# check launch agents
			agents=$(find "$HOME/Library/LaunchAgents" -mindepth 1 -maxdepth 1 2> /dev/null || true)
			if test "$agents" ; then
				printWarning 'Code execution point detected in launch agents'
				printInfo "$agents"
			fi
		'';
	};
}
