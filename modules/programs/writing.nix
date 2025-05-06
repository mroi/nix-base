{ config, lib, pkgs, ... }: {

	options.programs.writing.enable = lib.mkEnableOption "scientific writing tools";

	config = lib.mkIf config.programs.writing.enable (lib.mkMerge [

		{ environment.profile = [ "nix-base#texlive" ]; }

		(lib.mkIf pkgs.stdenv.isDarwin {

			environment.apps = [ 6612007609 ];  # Highland Pro

			environment.extensions."com.apple.quicklook.preview" = {
				"com.quoteunquoteapps.highland.pro.qlplugin" = true;
			};
		})
	]);
}
