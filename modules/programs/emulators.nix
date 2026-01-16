{ config, lib, pkgs, ... }: {

	options.programs.emulators.enable = lib.mkEnableOption "game console and home computer emulators";

	config = lib.mkIf config.programs.emulators.enable (lib.mkMerge [

		(lib.mkIf pkgs.stdenv.isDarwin {

			environment.bundles."/Applications/Games.localized/VICE.app" = {
				pkg = pkgs.callPackage ../../packages/vice.nix {};
				install = ''
					makeTree 755::admin "$out" "$pkg/Applications/VICE.app"
					checkSig "$out" 3RAEHPQQ6Z
				'';
			};

			system.activationScripts.bundles.text = lib.mkAfter ''
				if ! test -d /Applications/Games.localized/.localized ; then
					trace sudo tar -x --file=${./games-localized.tar.gz} --directory=/Applications/Games.localized
				fi
				makeIcon /Applications/Games.localized gamecontroller.fill
			'';

			system.files.known = [
				"/Applications/Games.localized"
				"/Applications/Games.localized/.localized"
				"/Applications/Games.localized/.localized/*"
			];
		})
	]);
}
