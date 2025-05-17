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

			programs.xcode.enable = lib.mkDefault true;
			programs.sfSymbols.enable = lib.mkDefault true;

			environment.bundles."/Applications/GitUp.app" = {
				pkg = pkgs.callPackage ../../packages/gitup.nix {};
				install = ''
					makeTree 755::admin "$out" "$pkg$out"
					checkSig "$out" FP44AY6HHW
				'';
			};
			environment.bundles."/Applications/Dash.app" = {
				pkg = pkgs.callPackage ../../packages/dash.nix {};
				install = ''
					makeTree 755::admin "$out" "$pkg$out"
					checkSig "$out" JP58VMK957
				'';
			};
		})
	]);
}
