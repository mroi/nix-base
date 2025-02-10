{ config, lib, ... }: {

	# ensure the Nix command is runnable
	# this setup is also performed in the last lines of install.sh, but is repeated here
	# for configurations, where Nix is not installed system-wide (nix.enable = false)
	config.system.activationScripts.nix = lib.mkIf (!config.nix.enable) ''
		if ! command -v nix > /dev/null ; then
			if $isLinux ; then sslCertFile=/etc/ssl/certs/ca-certificates.crt ; fi
			if $isDarwin ; then sslCertFile=/etc/ssl/cert.pem ; fi
			nix() {
				if test -x "''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile/bin/nix" ; then
					NIX_CONF_DIR=/nix NIX_SSL_CERT_FILE=$sslCertFile "''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile/bin/nix" "$@"
				else
					NIX_CONF_DIR=/nix NIX_SSL_CERT_FILE=$sslCertFile "$(find /nix/store/*-nix-*/bin/nix | sort --field-separator=- --key=3 | tail -n1)" "$@"
				fi
			}
		fi
	'';
}
