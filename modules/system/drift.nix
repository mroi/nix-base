{ config, lib, pkgs, ... }: {

	config.environment.loginHook.drift = lib.mkIf config.system.systemwideSetup (
		lib.optionalString (pkgs.stdenv.isDarwin && (config.nix.enable || config.users.guest.enable || config.users.defaultScriptShell != null)) (''
			# repair configuration drift after macOS updates
			os_version=$(sw_vers -productVersion)
			case "$os_version" in
			14.*|15.*|26.*)'' + "\n"
		+ lib.optionalString config.nix.enable (''
				if test "$(dscl . -read /Users/_nix PrimaryGroupID 2> /dev/null)" != ${toString config.users.groups.nix.gid} ; then
					dscl . -create /Users/_nix PrimaryGroupID ${toString config.users.groups.nix.gid}
				fi'' + "\n")
		+ lib.optionalString config.services.ollama.enable (''
				if test "$(dscl . -read /Users/_ollama PrimaryGroupID 2> /dev/null)" != ${toString config.users.groups._ollama.gid} ; then
					dscl . -create /Users/_ollama PrimaryGroupID ${toString config.users.groups._ollama.gid}
				fi'' + "\n")
		+ lib.optionalString config.users.guest.enable (''
				if ! dscl . -read /Users/Guest > /dev/null 2>&1 ; then
					dscl . -create /Users/Guest
					dscl . -create /Users/Guest UniqueID ${toString config.users.users.Guest.uid}
					dscl . -create /Users/Guest PrimaryGroupID 201
					dscl . -create /Users/Guest NFSHomeDirectory ${config.users.users.Guest.home}
					dscl . -create /Users/Guest UserShell ${config.users.users.Guest.shell}
					dscl . -create /Users/Guest RealName ${config.users.users.Guest.description}
					pwpolicy -getaccountpolicies | sed 1d > ${config.users.root.home}/globalpwpolicy.plist
					pwpolicy -clearaccountpolicies
					dscl . -passwd /users/Guest ""
					pwpolicy -setaccountpolicies ${config.users.root.home}/globalpwpolicy.plist
					rm ${config.users.root.home}/globalpwpolicy.plist
				fi'' + "\n")
		+ lib.optionalString (config.users.defaultScriptShell != null) (''
				if ! test -L /var/select/sh -a "$(readlink /var/select/sh)" = ${lib.escapeShellArg config.users.defaultScriptShell} ; then
					ln -shf ${lib.escapeShellArg config.users.defaultScriptShell} /var/select/sh
				fi'' + "\n")
		+ ''
				;;
			esac
		'')
	);
}
