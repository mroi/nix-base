{ config, lib, pkgs, ... }: {

	options.system = {

		checkSIP = lib.mkEnableOption "Warn if System Integrity Protection is not enabled.";
		checkSSV = lib.mkEnableOption "Warn if the Signed System Volume is not enabled.";
	};

	config = {

		system.checkSIP = lib.mkDefault pkgs.stdenv.isDarwin;
		system.checkSSV = lib.mkDefault pkgs.stdenv.isDarwin;

		assertions = [{
			assertion = ! config.system.checkSIP || pkgs.stdenv.isDarwin;
			message = "system.checkSIP is only available on Darwin";
		} {
			assertion = ! config.system.checkSSV || pkgs.stdenv.isDarwin;
			message = "system.checkSSV is only available on Darwin";
		}];

		system.activationScripts.sip = ''
			storeHeading

		'' + lib.optionalString config.system.checkSIP ''
			if ! csrutil status | head -n1 | grep -Fqw enabled ; then
				if csrutil status | head -n1 | grep -Fqw disabled ; then
					printWarning 'System Integrity Protection is disabled'
				else
					printWarning 'System Integrity Protection is not fully enabled'
				fi
				printInfo 'Restart the computer to recovery mode and run: csrutil enable'
			fi
		'' + lib.optionalString config.system.checkSSV ''
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
