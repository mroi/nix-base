{ config, lib, pkgs, ... }: {

	options.security.checks = {

		XProtect = lib.mkEnableOption "checking for XProtect malware scanner";
	};

	config = {

		security.checks.XProtect = lib.mkDefault pkgs.stdenv.hostPlatform.isDarwin;

		assertions = [{
			assertion = config.security.checks.XProtect -> pkgs.stdenv.hostPlatform.isDarwin;
			message = "security.checks.XProtect is only available on Darwin";
		}];

		system.activationScripts.checks = ''
			storeHeading -

		'' + lib.optionalString config.security.checks.XProtect ''
			if xprotect status --json | grep -Fqw false ; then
				printError 'XProtect malware scans are disabled'
			fi
		'';

		system.updateScripts.xprotect = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin ''
			storeHeading -
			trace sudo xprotect update
		'';
	};
}
