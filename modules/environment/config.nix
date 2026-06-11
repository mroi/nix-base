{ config, lib, pkgs, ... }: {

	options.environment.configurationProfiles = lib.mkOption {
		type = lib.types.nullOr (lib.types.listOf lib.types.path);
		default = null;
		description = "Configuration profile files to be installed in the system.";
	};

	config = let

		profiles = lib.pipe config.environment.configurationProfiles [
			(map (x: { file = x; name = builtins.baseNameOf x; }))
			(map (x: if lib.isStorePath x.file then x // { name = lib.substring 33 (-1) x.name; } else x))
		];
		profileNames = map (lib.getAttr "name") profiles;

		profileStaging = "${config.users.root.stagingDirectory}/profiles";

		profileHelpers = ''
			profileScope() {
				if plutil -extract PayloadScope raw "$1" > /dev/null 2>&1 ; then
					plutil -extract PayloadScope raw "$1"
				else
					echo User
				fi
			}

			profileCheck() {
				if ! test -r "$2" ; then
					printWarning "Profile file not readable: $2"
					return 0
				fi
				if test -f "$1" && cmp --quiet "$1" "$2" ; then
					# fast path says all OK
					return 0
				fi

				# otherwise check profile installation time
				name=$(basename "$1")
				uuid=$(plutil -extract PayloadUUID raw "$2")
				scope=$(profileScope "$2")
				echo
				printSubheading "Checking profile installation: $name"
				if ! test -f "$scope.plist" ; then
					case "$scope" in
					System)
						trace sudo profiles show -cached -output System.plist ;;
					User)
						trace profiles show -cached -output User.plist ;;
					esac
				fi
				# filter escape characters in some profiles, which confuse xmllint
				installTime=$(sed 's/\x1b//' "$scope.plist" | \
					xmllint --xpath "/plist/dict/array/dict[string[text()='$uuid']]/key[text()='ProfileInstallDate']/following-sibling::string[1]/text()" - 2> /dev/null || \
					echo '1970-01-01 00:00:00 +0000')
				installTime=$(date -jf "%Y-%m-%d %H:%M:%S %z" "$installTime" +%s)
				stagedTime=$(if test -f "$1" ; then stat -f %m "$1" ; else echo 0 ; fi)
				if test "$installTime" -gt "$stagedTime" ; then
					printInfo 'Profile was recently installed'
					cp "$2" "$1"
					chmod 644 "$1"
				else
					return 1
				fi
			}

			profileHints() {
				if grep -Eqw '(com.apple.mail.managed|com.apple.ews.account)' "$1" ; then
					printInfo
					printInfo 'Mail account payload in profile needs attention:'
					printInfo '• Account visibility in Notes.app'
					printInfo '• Account order and folder favorites in Mail.app'
					printInfo '• Account settings: attachment download, mail deletion'
					printInfo '• Visibility in focus mode filters'
				fi
				if grep -Fqw com.apple.caldav.account "$1" ; then
					printInfo
					printInfo 'CalDAV account payload in profile needs attention:'
					printInfo '• Account order in Calendar.app'
				fi
			}
		'';
		profileInstallScript = profile: ''
			if ! profileCheck "${profileStaging}/${profile.name}" '${profile.file}' ; then
				printDiff "${profileStaging}/${profile.name}" '${profile.file}'
				printWarning 'Manual profile installation required'
				printInfo '${profile.file}'
				profileHints '${profile.file}'
				if who | grep -Fw "$(id -un)" | grep -Fqw console ; then
					open '${profile.file}'
				fi
				if test -t 0 ; then
					printf '\n%s' 'Enter to continue...' >&2
					read -r _ < /dev/tty
				fi
				# clear cache of installed profiles and re-check
				rm -f "$(profileScope '${profile.file}').plist"
				profileCheck "${profileStaging}/${profile.name}" '${profile.file}' > /dev/null || true
			fi
		'';
		profileRemoveScript = profile: ''
			case "$(profileScope "${profile}")" in
			System)
				trace sudo profiles remove -path "${profile}" ;;
			User)
				trace profiles remove -path "${profile}" ;;
			esac
			# remove from staging
			rm "${profile}"
		'';

	in lib.mkIf (config.environment.configurationProfiles != null) {

		assertions = [{
			assertion = config.environment.configurationProfiles != [] -> pkgs.stdenv.isDarwin;
			message = "Configuration profiles are only supported on Darwin";
		} {
			assertion = lib.allUnique profileNames;
			message = "All profile files must have a unique name";
		}];

		system.activationScripts.config = lib.stringAfter [ "staging" ] ''
			storeHeading 'Managing configuration profiles'

			profiles='${lib.concatLines profileNames}'

			${profileHelpers}

			# check for migration to a new machine
			machine=$(ioreg -ard1 -c IOPlatformExpertDevice | \
				xmllint --xpath '/plist/array/dict/key[text()="IOPlatformUUID"]/following-sibling::string[1]/text()' -)
			if test ! -r "${profileStaging}/.machine" -o "$(cat "${profileStaging}/.machine")" != "$machine" ; then
				printInfo 'Initial profile installation on this machine'
				rm -f "${profileStaging}/"*
				makeDir 700 "${profileStaging}"
				echo "$machine" > "${profileStaging}/.machine"
			fi

			# remove profiles not in requested list
			for profile in "${profileStaging}/"* ; do
				if test -f "$profile" && ! hasLine "$profiles" "''${profile##*/}" ; then
					${profileRemoveScript "$profile"}
				fi
			done

			# install requested profiles
			${lib.concatLines (map profileInstallScript profiles)}

			rm -f System.plist User.plist
		'';

		# not strictly needed within the root folder, but setups may sync the files anyway
		system.activationScripts.root.deps = [ "config" ];

		system.files.known = [
			"/Library/Managed Preferences"
			"/Library/Managed Preferences/*"
		];
	};
}
