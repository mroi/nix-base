{ config, lib, pkgs, ... }: {

	options.programs.xcode = {
		enable = lib.mkEnableOption "Xcode";
		developerDir = lib.mkOption {
			type = lib.types.either (lib.types.enum [ "" ]) lib.types.path;
			default = "";
			description = "Selects a specific Xcode toolchain and SDK root to consult.";
		};
	};

	config = lib.mkIf config.programs.xcode.enable {

		assertions = [{
			assertion = ! config.programs.xcode.enable || pkgs.stdenv.isDarwin;
			message = "Xcode is only available on Darwin";
		}];

		environment.apps = [ 497799835 ];

		system.activationScripts.xcode = lib.stringAfter [ "apps" ] (let
			link = "/var/db/xcode_select_link";
			target = lib.escapeShellArg config.programs.xcode.developerDir;
		in ''
			storeHeading 'Xcode developer directory'
		'' + lib.optionalString (config.programs.xcode.developerDir == "") ''
			if test -L ${link} ; then
				trace sudo xcode-select --reset
			fi
		'' + lib.optionalString (config.programs.xcode.developerDir != "") ''
			if ! test -L ${link} -o "$(readlink ${link})" != ${target} ; then
				trace sudo xcode-select --switch ${target}
			fi
		'');

		# some non-sandboxed Nix builds may want to use the native Xcode toolchain
		system.activationScripts.bundles.deps = [ "xcode" ];
		system.activationScripts.profile.deps = [ "xcode" ];
	};
}
