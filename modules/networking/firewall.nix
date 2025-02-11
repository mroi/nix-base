{ config, lib, pkgs, ... }: {

	options.networking.firewall = {

		enable = lib.mkEnableOption "macOS application firewall";
		blockAll = lib.mkEnableOption "blocking of listening sockets for all applications";
		allowSystem = lib.mkEnableOption "listening sockets for system software";
		allowApps = lib.mkEnableOption "listening sockets for downloaded software";
		stealth = lib.mkEnableOption "stealth mode for the network stack";

		allow = lib.mkOption {
			type = lib.types.listOf lib.types.path;
			default = [];
			description = "These applications are allowed to create listening sockets.";
		};
		block = lib.mkOption {
			type = lib.types.listOf lib.types.path;
			default = [];
			description = "These applications are blocked from creating listening sockets.";
		};
	};

	config = let

		cfg = config.networking.firewall;
		applicable = config.system.systemwideSetup && pkgs.stdenv.isDarwin;

		socketfilterfw = "/usr/libexec/ApplicationFirewall/socketfilterfw";

		toOnOff = x: if x then "on" else "off";
		settingScript = nixOption: cliOption: ''
			checkFwSetting() { if ${socketfilterfw} "--get$1" | head -n1 | grep -Fiqw enabled ; then echo on ; else echo off ; fi ; }
			if test ${cliOption} = allowsignedapp ; then
				# special case as the CLI tools’s interface is not canonical
				checkFwSetting() { if ${socketfilterfw} --getallowsigned | head -n2 | grep -Fiqw enabled ; then echo on ; else echo off ; fi ; }
			fi
			if test "$(checkFwSetting ${cliOption})" != ${toOnOff nixOption} ; then
				trace sudo ${socketfilterfw} --set${cliOption} ${toOnOff nixOption}
			fi
		'';

		checkExe = var: ''
			if ! test -x "${var}" ; then
				printWarning "Executable missing: ${var}"
			fi
		'';

	in {

		networking.firewall.enable = lib.mkDefault applicable;

		assertions = [{
			assertion = ! cfg.enable || pkgs.stdenv.isDarwin;
			message = "Application firwall is only available on Darwin";
		} {
			assertion = ! cfg.enable || config.system.systemwideSetup;
			message = "Application firwall requires system-wide setup";
		} {
			assertion = cfg.enable || !(cfg.blockAll || cfg.allowSystem || cfg.allowApps || cfg.stealth || cfg.allow != [] || cfg.block != []);
			message = "Detailed application firewall settings require enabling the firewall";
		} {
			assertion = (lib.intersectLists cfg.allow cfg.block) == [];
			message = "An application cannot be simultaneously allowed and blocked by the application firewall";
		}];

		system.activationScripts.firewall = lib.mkIf applicable ''
			storeHeading Configuring the application firewall

			${settingScript cfg.enable "globalstate"}
			${settingScript cfg.blockAll "blockall"}
			${settingScript cfg.allowSystem "allowsigned"}
			${settingScript cfg.allowApps "allowsignedapp"}
			${settingScript cfg.stealth "stealthmode"}

			current="$(${socketfilterfw} --listapps | \
				sed -En '/^[0-9]* : /{s/ *$//;N;s/^.* : *(.*)\n.*(Allow|Block).*/\2 \1/;p;}')"
			allow="${lib.concatLines cfg.allow}"
			block="${lib.concatLines cfg.block}"

			# check current firewall settings for wrong entries
			forCurrent() {
				status="''${1%% *}"
				path="''${1#* }"

				if hasLine "$allow" "$path" ; then shouldAllow=true ; else shouldAllow=false ; fi
				if hasLine "$block" "$path" ; then shouldBlock=true ; else shouldBlock=false ; fi

				if ! $shouldAllow && ! $shouldBlock ; then
					trace sudo ${socketfilterfw} --remove "$path"
				else
					${checkExe "$path"}
				fi

				case "$status" in
				Allow)
					if ! $shouldAllow && $shouldBlock ; then
						trace sudo ${socketfilterfw} --blockapp "$path"
						current="$current''${newline}Block $path"
					fi ;;
				Block)
					if $shouldAllow && ! $shouldBlock ; then
						trace sudo ${socketfilterfw} --unblockapp "$path"
						current="$current''${newline}Allow $path"
					fi ;;
				esac
			}
			forLines "$current" forCurrent

			# scan for missing allow entries
			forAllow() {
				if ! hasLine "$current" "Allow $1" ; then
					${checkExe "$1"}
					if test -x "$1" ; then
						trace sudo ${socketfilterfw} --add "$1"
						trace sudo ${socketfilterfw} --unblockapp "$1"
					fi
				fi
			}
			forLines "$allow" forAllow

			# scan for missing block entries
			forBlock() {
				if ! hasLine "$current" "Block $1" ; then
					${checkExe "$1"}
					if test -x "$1" ; then
						trace sudo ${socketfilterfw} --add "$1"
						trace sudo ${socketfilterfw} --blockapp "$1"
					fi
				fi
			}
			forLines "$block" forBlock
		'';
	};
}
