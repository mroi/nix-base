{ config, lib, pkgs, ... }: {

	options.security.preferences.passwordProtect = lib.mkOption {
		type = lib.types.nullOr lib.types.bool;
		default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
			Linux = null;
			Darwin = true;
		};
		description = "Password-protect systemwide preferences.";
	};

	config = lib.mkIf (config.security.preferences.passwordProtect != null) {

		assertions = [{
			assertion = pkgs.stdenv.isDarwin;
			message = "Password-protection for systemwide preferences can only be configured on Darwin";
		} {
			assertion = config.security.preferences.passwordProtect;
			message = "Disabling password protection is currently not supported";
		}];

		system.activationScripts.prefsec = let
			expectedResult = lib.boolToString (! config.security.preferences.passwordProtect);
		in ''
			storeHeading 'Systemwide security preferences'

			shared=$(osascript -l JavaScript ${./prefsec-auth-shared.js})

			if test "$shared" != ${expectedResult} ; then
		'' + lib.getAttr expectedResult {
			true = ''
				fatalError 'Unknown which preference flags to update'
			'';
			false = ''
				trace sudo sqlite3 /var/db/auth.db "UPDATE rules SET flags = 10 WHERE name LIKE 'system.preferences%' AND flags = 11"
			'';
		} + ''
			fi
		'';
	};
}
