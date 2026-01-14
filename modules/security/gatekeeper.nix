{ config, lib, pkgs, ... }: {

	options.security.gatekeeper = {

		enable = lib.mkOption {
			type = lib.types.nullOr lib.types.bool;
			default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = null;
				Darwin = true;
			};
			description = "Enable Gatekeeper software assessment.";
		};
	};

	config = lib.mkIf (config.security.gatekeeper.enable != null) {

		assertions = [{
			assertion = config.security.gatekeeper.enable -> pkgs.stdenv.isDarwin;
			message = "Gatekeeper is only available on Darwin";
		}];

		system.activationScripts.gatekeeper = ''
			storeHeading 'Gatekeeper configuration'

			enable=${toString config.security.gatekeeper.enable}
			status=$(spctl --status | grep -Fcw enabled || true)

			case "$enable,$status" in
				1,0) trace sudo spctl --global-enable ;;
				0,1) trace sudo spctl --global-disable ;;
			esac
		'';
	};
}
