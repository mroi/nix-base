{ config, pkgs, lib, ... }: {

	options.system.distribution = lib.mkOption {
		type = lib.types.enum [ "generic" "elementaryOS" "macOS" ];
		default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
			Linux = "generic";
			Darwin = "macOS";
		};
		description = "The system distribution variant.";
	};

	config = lib.mkMerge [
		{
			assertions = [{
				assertion = config.system.distribution == "macOS" || pkgs.stdenv.isLinux;
				message = "The only supported Darwin variant is macOS";
			} {
				assertion = config.system.distribution != "macOS" || pkgs.stdenv.isDarwin;
				message = "System variant macOS is only supported on Darwin";
			}];
		}

		(lib.mkIf (config.system.distribution == "elementaryOS") {

			environment.apps = lib.mkIf (config.environment.flatpak == "system") [
				"io.elementary.calculator"
				"io.elementary.camera"
				"io.elementary.capnet-assist"
				"io.elementary.music"
				"io.elementary.screenshot"
				"io.elementary.videos"
				"org.gnome.Epiphany"
				"org.gnome.Evince"
				"org.gnome.FileRoller"
				"org.gnome.font-viewer"
			];
		})
	];
}
