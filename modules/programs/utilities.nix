{ config, lib, pkgs, ... }: {

	options.programs.utilities.enable = lib.mkEnableOption "utility applications";

	config = lib.mkIf config.programs.utilities.enable (lib.mkMerge [

		{ environment.profile = [ "nixpkgs#smartmontools" ]; }

		(lib.mkIf pkgs.stdenv.isDarwin {

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
