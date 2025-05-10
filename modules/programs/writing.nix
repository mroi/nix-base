{ config, lib, pkgs, ... }: {

	options.programs.writing.enable = lib.mkEnableOption "scientific writing tools";

	config = lib.mkIf config.programs.writing.enable (lib.mkMerge [

		{ environment.profile = [ "nix-base#texlive" ]; }

		(lib.mkIf pkgs.stdenv.isDarwin {

			environment.apps = [ 6612007609 ];  # Highland Pro

			environment.bundles."/Applications/Research.localized/LyX.app" = {
				pkg = pkgs.callPackage ../../packages/lyx.nix {};
				install = ''
					makeTree 755::admin "$out" "$pkg/Applications/LyX.app"
				'';
			};

			environment.extensions."com.apple.quicklook.preview" = {
				"com.quoteunquoteapps.highland.pro.qlplugin" = true;
			};
		})
	]);
}
