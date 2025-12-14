{ config, lib, pkgs, ... }: {

	options.services.timeMachine = {
		destinations = lib.mkOption {
			type = lib.types.nullOr (lib.types.listOf lib.types.str);
			default = [];
			description = "Backup destinations for Time Machine.";
		};
		includeVolumes = lib.mkOption {
			type = lib.types.listOf lib.types.path;
			default = [];
			description = "Additional volumes to be included in Time Machine backups.";
		};
		excludePaths = lib.mkOption {
			type = lib.types.listOf lib.types.path;
			default = [];
			description = "Paths to be excluded from Time Machine backups.";
		};
	};

	config = lib.mkIf (config.services.timeMachine.destinations != null) {

		assertions = [{
			assertion = config.services.timeMachine.destinations == [] || pkgs.stdenv.isDarwin;
			message = "Time Machine is only available on Darwin";
		} {
			assertion = lib.all (s: (lib.hasPrefix "/Volumes/" s) || (lib.hasInfix "://" s)) config.services.timeMachine.destinations;
			message = "Only local Time Machine destinations in /Volumes or network destinations are supported";
		}];

		warnings = lib.optional (config.services.timeMachine.destinations == [] && pkgs.stdenv.isDarwin)
			"No Time Machine backups configured for this machine";

		system.activationScripts.timemachine = lib.mkIf pkgs.stdenv.isDarwin (''
			storeHeading 'Configuring Time Machine backup'

			target='${lib.concatLines config.services.timeMachine.destinations}'
			current="$(tmutil destinationinfo -X | xmllint --xpath '(
				/plist/dict/array[*]/dict[key[text()="Kind"]/following-sibling::string[1]="Local"]/key[text()="Name"] |
				/plist/dict/array[*]/dict[key[text()="Kind"]/following-sibling::string[1]="Network"]/key[text()="URL"]
			)/following-sibling::string[1]/text()' - 2> /dev/null || true)"

			# remove destinations not in configured list
			forCurrent() {
				if test "''${1#*://}" = "$1" ; then
					# not a network storage destination
					dest=/Volumes/$1
				else
					dest=$1
				fi
				if ! hasLine "$target" "$dest" ; then
					uuids=$(tmutil destinationinfo -X | xmllint --xpath "(
						/plist/dict/array/dict[key[text()='Name']/following-sibling::string[1]='$1'] |
						/plist/dict/array/dict[key[text()='URL']/following-sibling::string[1]='$1']
					)/key[text()='ID']/following-sibling::string[1]/text()" - 2> /dev/null)
					for uuid in $uuids ; do
						trace sudo tmutil removedestination "$uuid"
					done
				fi
			}
			forLines "$current" forCurrent

			# add destinations not currently in time machine
			forTarget() {
				if ! hasLine "$current" "''${1#/Volumes/}" ; then
					trace sudo tmutil setdestination -ap "$1"
				fi
			}
			forLines "$target" forTarget

			# volume inclusions
		'' + (if (config.services.timeMachine.includeVolumes == []) then ''
			makePref /Library/Preferences/com.apple.TimeMachine.plist IncludedVolumeUUIDs delete
		'' else ''
			volumes='${lib.concatLines (lib.naturalSort config.services.timeMachine.includeVolumes)}'
			uuids=
			forVolume() {
				uuid=$(diskutil info -plist "$1" | xmllint --xpath '/plist/dict/key[text()="VolumeUUID"]/following-sibling::string[1]/text()' - 2> /dev/null || true)
				if test "$uuid" ; then
					uuids="$uuids$uuid "
				else
					fatalError "Cannot determine volume UUID: $1 is not mounted"
				fi
			}
			forLines "$volumes" forVolume
			# shellcheck disable=SC2086
			makePref /Library/Preferences/com.apple.TimeMachine.plist IncludedVolumeUUIDs array $uuids
		'') + ''

			# path exclusions
		'' + (if (config.services.timeMachine.excludePaths == []) then ''
			makePref /Library/Preferences/com.apple.TimeMachine.plist SkipPaths delete
		'' else ''
			makePref /Library/Preferences/com.apple.TimeMachine.plist SkipPaths array \
				${lib.escapeShellArgs (lib.naturalSort config.services.timeMachine.excludePaths)}
		'') + ''

			${config.system.cleanupScripts.timemachine}
		'');

		system.cleanupScripts.timemachine = lib.mkIf pkgs.stdenv.isDarwin ''
			storeHeading 'Checking Time Machine backup'

			lastBackups="$(/usr/libexec/PlistBuddy -x -c 'Print :Destinations' /Library/Preferences/com.apple.TimeMachine.plist 2> /dev/null | \
				xmllint --xpath '/plist/array[*]/dict/key[text()="SnapshotDates"]/following-sibling::array[1]/date[last()]/text()' - 2> /dev/null || true)"
			now=$(date +%s)

			# check for stale backup destinations
			for backup in $lastBackups ; do
				backupTime=$(date -jf "%Y-%m-%dT%H:%M:%S%Z" "''${backup%Z}GMT" +%s)
				backupAge=$((now - backupTime))
				if test "$backupAge" -gt 864000 ; then
					printWarning 'Time Machine destination not backed up for more than 10 days'
					break
				fi
			done
		'';
	};
}
