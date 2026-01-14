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

	in lib.mkIf isEnabled {

		assertions = [{
			assertion = isEnabled -> pkgs.stdenv.isDarwin;
			message = "Automatic updates of system software is only supported on Darwin";
		}];

		system.activationScripts.updates = ''
			storeHeading 'Automatic update settings'
		'' + lib.optionalString (cfg.autoDownload != null) ''
			makePref /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticDownload bool ${lib.boolToString cfg.autoDownload}
		'' + lib.optionalString (cfg.autoInstall == "none") ''
			makePref /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticallyInstallMacOSUpdates bool false
			makePref /Library/Preferences/com.apple.SoftwareUpdate.plist ConfigDataInstall bool false
			makePref /Library/Preferences/com.apple.SoftwareUpdate.plist CriticalUpdateInstall bool false
			makePref /Library/Preferences/com.apple.SoftwareUpdate.plist SplatEnabled bool false
		'' + lib.optionalString (cfg.autoInstall == "critical") ''
			makePref /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticallyInstallMacOSUpdates bool false
			makePref /Library/Preferences/com.apple.SoftwareUpdate.plist ConfigDataInstall bool true
			makePref /Library/Preferences/com.apple.SoftwareUpdate.plist CriticalUpdateInstall bool true
			makePref /Library/Preferences/com.apple.SoftwareUpdate.plist SplatEnabled bool true
		'' + lib.optionalString (cfg.autoInstall == "all") ''
			makePref /Library/Preferences/com.apple.SoftwareUpdate.plist AutomaticallyInstallMacOSUpdates bool true
			makePref /Library/Preferences/com.apple.SoftwareUpdate.plist ConfigDataInstall bool true
			makePref /Library/Preferences/com.apple.SoftwareUpdate.plist CriticalUpdateInstall bool true
			makePref /Library/Preferences/com.apple.SoftwareUpdate.plist SplatEnabled bool true
		'' + lib.optionalString (cfg.autoAppUpdate != null) ''
			makePref /Library/Preferences/com.apple.commerce.plist AutoUpdate bool ${lib.boolToString cfg.autoAppUpdate}
		'';

		system.updateScripts.system = lib.mkIf pkgs.stdenv.isDarwin ''
			storeHeading -
			trace softwareupdate --install --all
		'';
	};
}
