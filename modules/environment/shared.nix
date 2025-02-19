{ lib, pkgs, ... }: {

	options.environment.shared = {
		folder = lib.mkOption {
			type = lib.types.nullOr lib.types.path;
			default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = "/home/shared";
				Darwin = "/Users/Shared";
			};
			description = "Folder with files common across users.";
		};
	};
}
