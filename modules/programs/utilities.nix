{ config, lib, pkgs, ... }: {

	options.programs.utilities.enable = lib.mkEnableOption "utility applications";

	config = lib.mkIf config.programs.utilities.enable (lib.mkMerge [

		{ environment.profile = [ "nixpkgs#smartmontools" ]; }

		(lib.mkIf pkgs.stdenv.isDarwin {

			environment.apps = [
				1365531024  # 1Blocker
				1037126344  # Apple Configurator
				1352778147  # Bitwarden
				1381004916  # Discovery
				1358823008  # Flighty
				6444602274  # Ivory
				406825478   # Telefon
			];

			environment.bundles."/Applications/ImageOptim.app" = {
				pkg = pkgs.callPackage ../../packages/imageoptim.nix {};
				install = ''
					makeTree 755::admin "$out" "$pkg$out"
					checkSig "$out" 59KZTZA4XR
				'';
			};
			environment.extensions."com.apple.ui-services" = {
				"net.pornel.ImageOptimizeExtension" = true;
			};

			system.activationScripts.apps.text = lib.mkAfter ''
				makeIcon /Applications/Discovery.app ${./discovery-icon.cpgz}
			'';
		})
	]);
}
