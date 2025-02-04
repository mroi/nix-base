{ lib, config, pkgs, ... }: {

	options.security.sudo = {
		wheelNeedsPassword = lib.mkEnableOption "Whether users of the `wheel` group must provide a password to run `sudo`.";
		touchId = lib.mkEnableOption "Enable `sudo` authentication with Touch ID.";
	};

	config = {

		security.sudo.wheelNeedsPassword = lib.mkDefault true;
		security.sudo.touchId = lib.mkDefault pkgs.stdenv.isDarwin;

		assertions = [{
			assertion = ! config.security.sudo.touchId || pkgs.stdenv.isDarwin;
			message = "security.sudo.touchId is only available on Darwin";
		}];

		environment.patches = lib.optionals (!config.security.sudo.wheelNeedsPassword) [
			./sudo-group-wheel.patch
		] ++ lib.optionals config.security.sudo.touchId [
			./sudo-touch-id.patch
		];
	};
}
