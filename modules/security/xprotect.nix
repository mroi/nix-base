{ config, lib, pkgs, ... }: {

	options.security = {

		checkXProtect = lib.mkEnableOption "checking for XProtect malware scanner";
	};

	config = {

		security.checkXProtect = lib.mkDefault pkgs.stdenv.isDarwin;

		assertions = [{
			assertion = ! config.security.checkXProtect || pkgs.stdenv.isDarwin;
			message = "security.checkXProtect is only available on Darwin";
		}];

		system.activationScripts.xprotect = ''
			storeHeading -

		'' + lib.optionalString config.security.checkXProtect ''
			if xprotect status --json | grep -Fqw false ; then
				printWarning 'XProtect malware scans are disabled'
			fi
		'';

		system.updateScripts.xprotect = ''
			storeHeading -
			trace sudo xprotect update
		'';
	};
}
