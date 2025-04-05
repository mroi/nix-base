{ config, lib, pkgs, ... }: {

	options.users.guest.enable = lib.mkEnableOption "guest account" // { default = true; };

	config = lib.mkIf config.users.guest.enable (lib.mkMerge [

		(lib.mkIf pkgs.stdenv.isLinux {

			environment.patches = [
				./guest-lightdm-enable.patch
				./guest-sandbox-shared-data.patch
			];
		})

		(lib.mkIf pkgs.stdenv.isDarwin {

			# guest account not officially supported with FileVault, create our own
			users.users.Guest = {
				uid = 201;
				group = "_guest";
				isHidden = false;
				home = "/Users/Guest";
				shell = "/bin/zsh";
				description = lib.mkDefault "Guest User";
			};

			system.activationScripts.guest = lib.stringAfter [ "users" ] ''
				storeHeading 'Empty password for guest account'

				if ! dscl . -authonly Guest "" > /dev/null 2>&1 ; then
					# set empty guest password by temporarily clearing the password policy
					pwpolicy -getaccountpolicies | sed 1d > globalpwpolicy.plist
					trace sudo pwpolicy -clearaccountpolicies
					trace sudo dscl . -passwd /users/Guest ""
					trace sudo pwpolicy -setaccountpolicies globalpwpolicy.plist
					rm globalpwpolicy.plist
					# refresh potential user list in Control Center
					trace pkill ControlCenter
				fi
			'';

			environment.loginHook.guest = ''
				# guest account login
				if test "$USER" = Guest ; then
					# mark account as proper guest to skip account setup
					dscl . -create /users/Guest _guest true
				else
					# unmark the guest account, otherwise it does not show up in fast user switching
					dscl . -delete /users/Guest _guest || true
					defaults delete /Library/Preferences/com.apple.loginwindow.plist GuestEnabled || true
				fi
			'';
			environment.logoutHook.guest = ''
				# delete the guest account home directory after logout
				if test "$USER" = Guest ; then (sleep 5 ; rm -rf /Users/Guest) & fi
			'';
		})
	]);
}
