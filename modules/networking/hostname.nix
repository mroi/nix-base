{ config, lib, pkgs, ... }: {

	options.networking.hostName = lib.mkOption {
		type = lib.types.nullOr (lib.types.strMatching "[a-z-]+");
		description = "The name of the machine.";
	};

	config.system.activationScripts.hostname = let

		cmd = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
			Linux = {
				getPrettyName = "hostnamectl hostname --pretty";
				setPrettyName = "hostnamectl hostname --pretty";
				getStaticName = "hostnamectl hostname --static";
				setStaticName = "hostnamectl hostname --static";
			};
			Darwin = {
				getPrettyName = "scutil --get ComputerName";
				setPrettyName = "scutil --set ComputerName";
				getStaticName = "scutil --get LocalHostName";
				setStaticName = "scutil --set LocalHostName";
			};
		};
		capitalize = s: (lib.toUpper (lib.substring 0 1 s)) + (lib.substring 1 (-1) s);

	in lib.mkIf (config.networking.hostName != null) ''
		storeHeading 'Configure machine name'
		if test "$(${cmd.getPrettyName})" != '${capitalize config.networking.hostName}' ; then
			trace sudo ${cmd.setPrettyName} '${capitalize config.networking.hostName}'
		fi
		if test "$(${cmd.getStaticName})" != '${lib.toLower config.networking.hostName}' ; then
			trace sudo ${cmd.setStaticName} '${lib.toLower config.networking.hostName}'
		fi
	'';
}
