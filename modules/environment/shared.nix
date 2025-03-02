{ config, lib, pkgs, ... }: {

	options.environment.shared = {
		folder = lib.mkOption {
			type = lib.types.nullOr lib.types.path;
			default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = "/home/shared";
				Darwin = "/Users/Shared";
			};
			description = "Folder with files common across users.";
		};
		exeDir = lib.mkOption {
			type = lib.types.path;
			default = if config.environment.shared.folder != null then
				"${config.environment.shared.folder}/.local/bin" else "";
			description = "Directory with executables common across users.";
		};
	};

	config = lib.mkIf (config.environment.shared.folder != null) {

		system.activationScripts.shared = lib.mkIf pkgs.stdenv.isDarwin ''
			storeHeading -

			# prompt the user to delete relocated items
			find "${config.environment.shared.folder}/"*Relocated\ Items* > relocated 2> /dev/null || true
			interactiveDeletes relocated 'These files got moved to ${config.environment.shared.folder} by a macOS update.'
			rm relocated
		'';
	};
}
