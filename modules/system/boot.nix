{ config, lib, pkgs, ... }: {

	options.system.boot.chime = lib.mkOption {
		type = lib.types.nullOr lib.types.bool;
		default = pkgs.stdenv.isDarwin;
		description = "Enable the startup chime.";
	};

	config = lib.mkIf (config.system.boot.chime != null) {

		assertions = [{
			assertion = ! config.system.boot.chime || pkgs.stdenv.isDarwin;
			message = "Startup chime is only available on Darwin";
		}];

		system.nvram = lib.mkIf pkgs.stdenv.isDarwin {
			StartupMute = if config.system.boot.chime then null else "%01";
		};
	};
}
