{ config, lib, pkgs, ... }: {

	config.environment.loginHook.drift = lib.mkIf config.system.systemwideSetup (
		lib.optionalString (pkgs.stdenv.isDarwin && (config.nix.enable || config.users.guest.enable)) (''
			# repair configuration drift after macOS updates
			os_version=$(sw_vers -productVersion)
			if test "$os_version" != "''${os_version#15.}" ; then'' + "\n"
		+ lib.optionalString config.nix.enable (''
				if ! dscl . -read /Users/_nix PrimaryGroupID > /dev/null 2>&1 ; then
					dscl . -create /Users/_nix PrimaryGroupID ${toString config.users.groups.nix.gid}
				fi'' + "\n")
		+ lib.optionalString config.users.guest.enable (''
				if ! dscl . -read /Users/Guest > /dev/null 2>&1 ; then
					dscl . -create /Users/Guest
					dscl . -create /Users/Guest UniqueID ${toString config.users.users.Guest.uid}
					dscl . -create /Users/Guest PrimaryGroupID 201
					dscl . -create /Users/Guest NFSHomeDirectory ${config.users.users.Guest.home}
					dscl . -create /Users/Guest UserShell ${config.users.users.Guest.shell}
					dscl . -create /Users/Guest RealName ${config.users.users.Guest.description}
					pwpolicy -getaccountpolicies | sed 1d > /var/root/globalpwpolicy.plist
					pwpolicy -clearaccountpolicies
					dscl . -passwd /users/Guest ""
					pwpolicy -setaccountpolicies /var/root/globalpwpolicy.plist
					rm /var/root/globalpwpolicy.plist
				fi'' + "\n")
		+ ''
			fi
		'')
	);
}
