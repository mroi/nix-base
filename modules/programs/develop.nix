{ config, lib, pkgs, ... }: {

	options.programs.develop.enable = lib.mkEnableOption "developer programs";

	config = lib.mkIf config.programs.develop.enable (lib.mkMerge [

		(lib.mkIf pkgs.stdenv.isLinux {
			environment.profile = [
				"nixpkgs#git"
				"nixpkgs#swift"
			];
		})

		(lib.mkIf pkgs.stdenv.isDarwin {
			programs.xcode.enable = true;
		})
	]);
}
