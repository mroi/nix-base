{ config, lib, pkgs, ... }: {

	options.security.checks = {

		XProtect = lib.mkEnableOption "checking for XProtect malware scanner";
	};

	config = {

		security.checks.XProtect = lib.mkDefault pkgs.stdenv.isDarwin;

		assertions = [{
			assertion = config.security.checks.XProtect -> pkgs.stdenv.isDarwin;
			message = "security.checks.XProtect is only available on Darwin";
		}];

		system.activationScripts.checks = ''
			storeHeading -

		'' + lib.optionalString config.security.checks.XProtect ''
			if xprotect status --json | grep -Fqw false ; then
				printError 'XProtect malware scans are disabled'
			fi
		'';

		system.updateScripts.xprotect = lib.mkIf pkgs.stdenv.isDarwin ''
			storeHeading -
			trace sudo xprotect update
		'';
	};
}
