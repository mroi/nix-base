{ config, lib, pkgs, ... }: {

	options.users.guest.enable = lib.mkEnableOption "guest account" // { default = true; };

	config = lib.mkIf config.users.guest.enable {

		environment.patches = lib.optionals pkgs.stdenv.isLinux [
			./guest-lightdm-enable.patch
			./guest-sandbox-shared-data.patch
		];
	};
}
