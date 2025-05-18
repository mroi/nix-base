{ config, lib, pkgs, ... }: {

	options.services.openssh.passwordlessKeys = lib.mkOption {
		type = lib.types.listOf (lib.types.pathWith { inStore = false; });
		default = [];
		description = "List of keys for which passwordless use is ensured by storing the password.";
	};

	config = let

		keyScript = file: let
			path = if lib.hasPrefix "/" file then file else "$HOME/.ssh/${file}";
		in ''
			if ! hasLine "$stored" "${path}" ; then
				trace ssh-add -c --apple-use-keychain "${path}"
				trace ssh-add -d "${path}"
			fi
		'';

	in {

		assertions = [{
			assertion = config.services.openssh.passwordlessKeys == [] || pkgs.stdenv.isDarwin;
			message = "Storing SSH key passwords is only supported on Darwin";
		}];

		system.activationScripts.sshkeys = lib.mkIf (config.services.openssh.passwordlessKeys != []) ''
			storeHeading 'Storing SSH key passwords'

			# load all keys to the ssh agent with stored passwords
			stored=$(ssh-add -c --apple-load-keychain 2>&1 | sed -n '/^Identity added:/{s/^Identity added: //;s/ (.*)$//;p;}')

			# ask and store password for keys that should be passwordless
			${lib.concatLines (map keyScript config.services.openssh.passwordlessKeys)}

			# remove stored keys from the ssh agent
			oldIFS=$IFS
			IFS=$(printf '\n\t')
			# shellcheck disable=SC2086
			ssh-add -d $stored 2> /dev/null
			IFS=$oldIFS
		'';
	};
}
