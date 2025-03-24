{ config, lib, pkgs, ... }: {

	options.time.timeZone = lib.mkOption {
		type = lib.types.nullOr lib.types.str;
		default = null;
		example = "Europe/Berlin";
		description = "The time zone used when displaying times and dates.";
	};

	config.system.activationScripts.timezone = lib.mkIf (config.time.timeZone != null) (''
		storeHeading 'Set time zone'
	'' + lib.optionalString pkgs.stdenv.isLinux ''
		if test "$(timedatectl show --property=Timezone --value)" != '${config.time.timeZone}' ; then
			trace sudo timedatectl set-timezone '${config.time.timeZone}'
		fi
	'' + lib.optionalString pkgs.stdenv.isDarwin ''
		if test "$(readlink /etc/localtime)" != '/var/db/timezone/zoneinfo/${config.time.timeZone}' ; then
			trace sudo systemsetup -settimezone '${config.time.timeZone}'
		fi
	'');
}
