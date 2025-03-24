{ config, lib, pkgs, ... }: {

	options.system.updates = {
		autoDownload = lib.mkOption {
			type = lib.types.nullOr lib.types.bool;
			default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = null;
				Darwin = true;
			};
			description = "Automatic download of system software updates.";
		};
		autoInstall = lib.mkOption {
			type = lib.types.nullOr (lib.types.enum [ "none" "critical" "all" ]);
			default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = null;
				Darwin = "all";
			};
			description = "Automatic installation of system software updates.";
		};
		autoAppUpdate = lib.mkOption {
			type = lib.types.nullOr lib.types.bool;
			default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = null;
				Darwin = true;
			};
			description = "Automatic update of applications.";
		};
	};

	config = let

		cfg = config.system.updates;
		isEnabled = (cfg.autoDownload != null) || (cfg.autoInstall != null) || (cfg.autoAppUpdate != null);

		settingScript = plist: key: value: ''
			if test "$(defaults read ${plist} ${key})" != ${if value then "1" else "0"} ; then
				trace sudo defaults write ${plist} ${key} -bool ${lib.boolToString value}
			fi
		'';

	in lib.mkIf isEnabled {

		assertions = [{
			assertion = isEnabled || pkgs.stdenv.isDarwin;
			message = "Automatic updates of system software is only supported on Darwin";
		}];

		system.activationScripts.updates = ''
			storeHeading 'Automatic update settings'
		'' + lib.optionalString (cfg.autoDownload != null) ''
			${settingScript "/Library/Preferences/com.apple.SoftwareUpdate" "AutomaticDownload" cfg.autoDownload}
		'' + lib.optionalString (cfg.autoInstall == "none") ''
			${settingScript "/Library/Preferences/com.apple.SoftwareUpdate" "AutomaticallyInstallMacOSUpdates" false}
			${settingScript "/Library/Preferences/com.apple.SoftwareUpdate" "ConfigDataInstall" false}
			${settingScript "/Library/Preferences/com.apple.SoftwareUpdate" "CriticalUpdateInstall" false}
		'' + lib.optionalString (cfg.autoInstall == "critical") ''
			${settingScript "/Library/Preferences/com.apple.SoftwareUpdate" "AutomaticallyInstallMacOSUpdates" false}
			${settingScript "/Library/Preferences/com.apple.SoftwareUpdate" "ConfigDataInstall" true}
			${settingScript "/Library/Preferences/com.apple.SoftwareUpdate" "CriticalUpdateInstall" true}
		'' + lib.optionalString (cfg.autoInstall == "all") ''
			${settingScript "/Library/Preferences/com.apple.SoftwareUpdate" "AutomaticallyInstallMacOSUpdates" true}
			${settingScript "/Library/Preferences/com.apple.SoftwareUpdate" "ConfigDataInstall" true}
			${settingScript "/Library/Preferences/com.apple.SoftwareUpdate" "CriticalUpdateInstall" true}
		'' + lib.optionalString (cfg.autoAppUpdate != null) ''
			${settingScript "/Library/Preferences/com.apple.commerce" "AutoUpdate" cfg.autoAppUpdate}
		'';
	};
}
