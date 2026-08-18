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
			assertion = config.programs.xcode.enable -> pkgs.stdenv.hostPlatform.isDarwin;
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
					if test -r "$out/Contents/Info.plist" ; then
						version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$out/Contents/Info.plist")
					else
						version=0
					fi
					if test -r "$out/Contents/Resources/BetaVersion.plist" ; then
						seed=$(/usr/libexec/PlistBuddy -c 'Print :seedNumber' "$out/Contents/Resources/BetaVersion.plist")
					else
						seed=0
					fi
					installed="Xcode ''${version%.*} Beta $seed"

					available=$(curl --silent https://developer.apple.com/tutorials/data/index/xcode-release-notes | \
						jq --raw-output 'first(.interfaceLanguages.swift[0].children[] | select(.type == "article")).title | rtrimstr(" Release Notes")')
					if test "$available" != "''${available% Beta *}" ; then
						if test "$installed" != "$available" ; then
							printWarning 'New Xcode Beta version available'
							printInfo "Download $available and manuall install to $out:"
							printInfo 'https://developer.apple.com/download/all/?q=Xcode'
						fi
					else
						printWarning "Current $available release is not a Beta version"
						printInfo 'Consider disabling Nix option programs.xcode.beta'
					fi
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

		system.files.known = [
			"/Library/Apple/System/Library/Extensions/RemoteVirtualInterface.kext"
			"/Library/Apple/System/Library/Extensions/RemoteVirtualInterface.kext/*"
			"/Library/Apple/System/Library/LaunchDaemons/com.apple.rpmuxd.plist"
			"/Library/Apple/usr"
			"/Library/Apple/usr/bin"
			"/Library/Apple/usr/bin/rvictl"
			"/Library/Apple/usr/libexec"
			"/Library/Apple/usr/libexec/rpmuxd"
			"/Library/Developer/CoreSimulator/*"
			"/Library/Developer/DeveloperDiskImages"
			"/Library/Developer/DeveloperDiskImages/*"
			"/private/etc/paths.d/100-rvictl"
		];
	};
}
