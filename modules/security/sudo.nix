{ config, lib, pkgs, ... }: {

	options.security.sudo = {
		wheelNeedsPassword = lib.mkEnableOption "password check for users of the `wheel` group to run `sudo`" // {
			default = true;
		};
		touchId = lib.mkEnableOption "`sudo` authentication with Touch ID" // {
			default = pkgs.stdenv.isDarwin;
		};
		adminFlagFile = lib.mkEnableOption "flag file `.sudo_as_admin_successful`";
	};

	config = {

		assertions = [{
			assertion = ! config.security.sudo.touchId || pkgs.stdenv.isDarwin;
			message = "security.sudo.touchId is only available on Darwin";
		} {
			assertion = ! config.security.sudo.adminFlagFile || pkgs.stdenv.isLinux;
			message = "security.sudo.adminFlagFile is only available on Linux";
		}];

		environment.patches = lib.optionals (!config.security.sudo.wheelNeedsPassword) [
			./sudo-group-wheel.patch
		] ++ lib.optionals config.security.sudo.touchId [
			./sudo-touch-id.patch
		] ++ lib.optionals (pkgs.stdenv.isLinux && ! config.security.sudo.adminFlagFile) [{
			patch = ./sudo-no-admin-flag.patch;
			doCheck = false;
		}];
	};
}
