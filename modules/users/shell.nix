{ config, lib, pkgs, ... }: {

	options.users = {
		defaultScriptShell = lib.mkOption {
			type = lib.types.nullOr lib.types.path;
			default = "/bin/dash";
			description = "Shell implementation to be used for scripts using `/bin/sh` as interpreter.";
		};
		binDir = lib.mkOption {
			type = lib.types.pathWith { absolute = false; };
			default = ".local/bin";
			description = "Relative directory within user’s home where executables are stored (see `$XDG_BIN_HOME`).";
		};
		serviceDir = lib.mkOption {
			type = lib.types.pathWith { absolute = false; };
			default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = ".local/libexec";
				Darwin = "Library/CoreServices";
			};
			description = "Relative directory within user’s home where service executables are stored.";
		};
		stateDir = lib.mkOption {
			type = lib.types.pathWith { absolute = false; };
			default = ".local/state";
			description = "Relative directory within user’s home where state files are stored (see `$XDG_STATE_HOME`).";
		};
	};

	config = lib.mkIf (config.users.defaultScriptShell != null) {

		system.activationScripts.shell = ''
			storeHeading 'Select default script shell'

			shell=${lib.escapeShellArg config.users.defaultScriptShell}
			if test -x "$shell" ; then
		'' + lib.optionalString pkgs.stdenv.isLinux ''
				if ! test -L /bin/sh -a "$(readlink /bin/sh)" = "''${shell#/bin/}" ; then
					printError "The shell $shell must be installed as a dpkg diversion at /bin/sh"
				fi
		'' + lib.optionalString pkgs.stdenv.isDarwin ''
				makeLink 755:root:wheel /var/select/sh "$shell"
		'' + ''
			else
				fatalError "The shell $shell is not an executable file"
			fi
		'';
	};
}
