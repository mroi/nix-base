{ config, lib, pkgs, ... }: {

	options.programs.xcode = {
		enable = lib.mkEnableOption "Xcode";
		developerDir = lib.mkOption {
			type = lib.types.either (lib.types.enum [ "" ]) lib.types.path;
			default = "";
			description = "Selects a specific Xcode toolchain and SDK root to consult.";
		};
		beta = lib.mkEnableOption "Xcode beta version";
	};

	config = lib.mkIf config.programs.xcode.enable {

		assertions = [{
			assertion = ! config.programs.xcode.enable || pkgs.stdenv.isDarwin;
			message = "Xcode is only available on Darwin";
		}];

		environment.apps = lib.mkIf (!config.programs.xcode.beta) [ 497799835 ];
		environment.bundles = lib.mkIf config.programs.xcode.beta {
			"/Applications/Xcode.app" = {
				pkg = derivation {
					name = "xcode-beta-dummy";
					builder = "/bin/sh";
					args = [ "-c" "echo > $out" ];
					system = pkgs.stdenv.system;
					version = null;
				};
				install = ''
					printInfo 'Check here for current Xcode beta versions:'
					printInfo 'https://developer.apple.com/download/all/?q=Xcode'
					printInfo "Install manually to $out"
					unset out
				'';
			};
		};

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
