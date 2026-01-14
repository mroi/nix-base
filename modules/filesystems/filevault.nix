{ config, lib, pkgs, ... }: {

	config = lib.mkIf (config ? fileSystems."/") {

		assertions = [{
			assertion = config.fileSystems."/".encrypted -> pkgs.stdenv.isDarwin;
			message = "Root volume encryption is only available on Darwin";
		}];

		system.activationScripts.filevault = ''
			storeHeading 'FileVault configuration'

			enable=${toString config.fileSystems."/".encrypted}
			status=$(fdesetup status | grep -Fcw 'is On' || true)

			case "$enable,$status" in
				1,0) trace sudo fdesetup enable ;;
				0,1) trace sudo fdesetup disable ;;
			esac
		'';
	};
}
