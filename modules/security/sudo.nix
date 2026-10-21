{ config, lib, pkgs, ... }: {

	options.security.sudo = {
		wheelNeedsPassword = lib.mkEnableOption "password check for users of the `wheel` group to run `sudo`" // {
			default = true;
		};
		touchId = lib.mkEnableOption "`sudo` authentication with Touch ID" // {
			default = pkgs.stdenv.hostPlatform.isDarwin;
		};
	};

	config = {

		assertions = [{
			assertion = config.security.sudo.touchId -> pkgs.stdenv.hostPlatform.isDarwin;
			message = "security.sudo.touchId is only available on Darwin";
		}];

		environment.patches = lib.optionals (!config.security.sudo.wheelNeedsPassword) [
			./sudo-group-wheel.patch
		] ++ lib.optionals config.security.sudo.touchId [
			./sudo-touch-id.patch
		];

		system.files.known = let
			prefix = if pkgs.stdenv.hostPlatform.isDarwin then "/private" else "";
		in lib.optionals (!config.security.sudo.wheelNeedsPassword) [
			"${prefix}/etc/sudoers.d/group-wheel"
		] ++ lib.optionals config.security.sudo.touchId [
			"${prefix}/etc/pam.d/sudo_local"
		];
	};
}
