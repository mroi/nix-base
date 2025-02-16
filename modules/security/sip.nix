{ config, lib, pkgs, ... }: {

	options.security = {

		checkSIP = lib.mkEnableOption "checking for System Integrity Protection";
		checkSSV = lib.mkEnableOption "checking for Signed System Volume";
	};

	config = {

		security.checkSIP = lib.mkDefault pkgs.stdenv.isDarwin;
		security.checkSSV = lib.mkDefault pkgs.stdenv.isDarwin;

		assertions = [{
			assertion = ! config.security.checkSIP || pkgs.stdenv.isDarwin;
			message = "security.checkSIP is only available on Darwin";
		} {
			assertion = ! config.security.checkSSV || pkgs.stdenv.isDarwin;
			message = "security.checkSSV is only available on Darwin";
		}];

		system.activationScripts.sip = ''
			storeHeading -

		'' + lib.optionalString config.security.checkSIP ''
			if ! csrutil status | head -n1 | grep -Fqw enabled ; then
				if csrutil status | head -n1 | grep -Fqw disabled ; then
					printWarning 'System Integrity Protection is disabled'
				else
					printWarning 'System Integrity Protection is not fully enabled'
				fi
				printInfo 'Restart the computer to recovery mode and run: csrutil enable'
			fi
		'' + lib.optionalString config.security.checkSSV ''
			if ! csrutil authenticated-root status | head -n1 | grep -Fqw enabled ; then
				if csrutil authenticated-root status | head -n1 | grep -Fqw disabled ; then
					printWarning 'Booting from sealed system snapshot is disabled'
				else
					printWarning 'Booting from sealed system snapshot is not fully enabled'
				fi
				printInfo 'Restart the computer to recovery mode and run: csrutil authenticated-root enable'
			fi
		'';
	};
}
