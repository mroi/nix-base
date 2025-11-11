{ config, lib, pkgs, options, ... }: {

	options.security.checks = {

		SIP = lib.mkEnableOption "checking for System Integrity Protection";
		SSV = lib.mkEnableOption "checking for Signed System Volume";
		injection = lib.mkEnableOption "checking for unwanted code injection";
		execution = lib.mkEnableOption "checking for unwanted code execution";

		known = lib.mkOption {
			type = lib.types.listOf lib.types.str;
			default = [];
			description = "A list of known-good items for the code injection or code execution checks.";
		};
	};

	config = let

		enableOptions = [ "SIP" "SSV" "injection" "execution" ];

	in {

		security.checks = lib.genAttrs enableOptions (_: lib.mkDefault pkgs.stdenv.isDarwin);

		assertions = let
			darwinOnly = option: {
				assertion = ! config.security.checks."${option}" || pkgs.stdenv.isDarwin;
				message = "security.checks.${option} is only available on Darwin";
			};
		in map darwinOnly enableOptions;

		system.activationScripts.checks = ''
			storeHeading -

			# shellcheck disable=SC2034
			known="${lib.concatLines config.security.checks.known}"

		'' + lib.optionalString config.security.checks.SIP ''
			if ! csrutil status | head -n1 | grep -Fqw enabled ; then
				if csrutil status | head -n1 | grep -Fqw disabled ; then
					printWarning 'System Integrity Protection is disabled'
				else
					printWarning 'System Integrity Protection is not fully enabled'
				fi
				printInfo 'Restart the computer to recovery mode and run: csrutil enable'
			fi
		'' + lib.optionalString config.security.checks.SSV ''
			if ! csrutil authenticated-root status | head -n1 | grep -Fqw enabled ; then
				if csrutil authenticated-root status | head -n1 | grep -Fqw disabled ; then
					printWarning 'Booting from sealed system snapshot is disabled'
				else
					printWarning 'Booting from sealed system snapshot is not fully enabled'
				fi
				printInfo 'Restart the computer to recovery mode and run: csrutil authenticated-root enable'
			fi

		'' + lib.optionalString config.security.checks.injection ''
			storeHeading -

			# check plugin directories
			while read -r dir ; do
				plugins=$(find "$dir" -mindepth 1 -maxdepth 1 ! -name .localized 2> /dev/null || true)
				first=true
				forPlugin() {
					if ! hasLine "$known" "$1" ; then
						if $first ; then printWarning 'Code injection point detected in plugin directory' ; fi
						first=false
						printInfo "$1"
					fi
				}
				forLines "$plugins" forPlugin
			done <<- EOF
				$HOME/Library/Address Book Plug-Ins
				$HOME/Library/Input Methods
				$HOME/Library/Internet Plug-Ins
				$HOME/Library/PreferencePanes
				$HOME/Library/iTunes/iTunes Plug-ins
			EOF

		'' + lib.optionalString config.security.checks.execution ''
			storeHeading -

			# check preferences governing code execution
			while read -r domain key ; do
				if ! hasLine "$known" "$domain/$key" ; then
					if defaults read "$domain" "$key" > /dev/null 2>&1 ; then
						printWarning 'Code execution point detected in preferences'
						printInfo "$domain/$key"
					fi
				fi
			done <<- EOF
				com.apple.FolderActions folderActions
				com.apple.scheduler AbsoluteSchedule
			EOF

			# check login items
			loginitems=/var/db/com.apple.xpc.launchd/loginitems.$(id -u).plist
			if test -f "$loginitems" && ! hasLine "$known" "$loginitems" ; then
				printWarning 'Code execution point detected in login items'
				printInfo "$loginitems"
			fi

			# check launch agents
			agents=$(find "$HOME/Library/LaunchAgents" -mindepth 1 -maxdepth 1 2> /dev/null || true)
			first=true
			forAgents() {
				if ! hasLine "$known" "$1" ; then
					if $first ; then printWarning 'Code execution point detected in launch agents' ; fi
					first=false
					printInfo "$1"
				fi
			}
			forLines "$agents" forAgents
		'';
	};
}
