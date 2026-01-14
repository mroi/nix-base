{ config, lib, pkgs, ... }: {

	options.programs.affinity.enable = lib.mkEnableOption "Affinity application suite";

	config = lib.mkIf config.programs.affinity.enable {

		assertions = [{
			assertion = config.programs.affinity.enable -> pkgs.stdenv.isDarwin;
			message = "Affinity is only available on Darwin";
		}];

		# FIXME: Affinity apps are discontinued, now single side-loaded app from https://www.affinity.studio/
		# wait for potential Pixelmator successor from Apple?
		environment.apps = [ 1616831348 1616822987 1606941598 ];

		environment.extensions = {
			"com.apple.photo-editing" = {
				"com.seriflabs.affinityphoto2.AffinityExtension" = true;
			};
			"com.apple.quicklook.preview" = {
				"com.seriflabs.affinitydesigner2.QuickLookShareExtension" = true;
				"com.seriflabs.affinityphoto2.QuickLookShareExtension" = true;
				"com.seriflabs.affinitypublisher2.QuickLookShareExtension" = true;
			};
		};
	};
}
