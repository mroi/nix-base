{ config, lib, pkgs, ... }: {

	options.environment = {

		loginHook = lib.mkOption {
			type = lib.types.attrsOf lib.types.str;
			default = {};
			description = "A set of shell script fragments that execute when a user logs in.";
		};
		logoutHook = lib.mkOption {
			type = lib.types.attrsOf lib.types.str;
			default = {};
			description = "A set of shell script fragments that execute when a user logs out.";
		};
	};

	config = let

		fragments = [ "volumes" "guest" "unison" "drift" "extra" ];

		unknownFragmentAssertion = name: set:
			let unknownFragments = lib.subtractLists fragments (lib.attrNames set);
			in {
				assertion = unknownFragments == [];
				message = "Unknown entry in ${name}: ${lib.concatStringsSep " " unknownFragments}";
			};

		stripTabs = text: let
			hasTabs = lines: lib.all (lib.hasPrefix "\t") (lib.take 1 lines);
			stripOneTab = map (lib.removePrefix "\t");
			stripMaxTabs = lines: if (hasTabs lines) then (stripMaxTabs (stripOneTab lines)) else lines;
		in lib.pipe text [
			(lib.splitString "\n")
			stripMaxTabs
			(lib.concatStringsSep "\n")
		];

		generateHook = type: pkgs.writeTextFile {
			name = "${type}-hook.sh";
			text = lib.concatLines ([
				"#!/bin/sh -e"
				""
				"PATH=/bin:/sbin:/usr/bin:/usr/sbin"
			] ++ lib.optionals pkgs.stdenv.isDarwin [
				"USER=$1"
			]) + lib.pipe fragments [
				(map (f: config.environment."${type}Hook"."${f}" or ""))
				(map stripTabs)
				(lib.concatMapStrings (s: if s == "" then "" else "\n" + s))
			];
			checkPhase = ''
				${pkgs.stdenv.shellDryRun} "$out"
				${lib.getExe pkgs.shellcheck} "$out"
			'';
		};

		loginHook = generateHook "login";
		logoutHook = generateHook "logout";

		preservePasswords = source: target: ''
			# existing ${target} in staging may contain passwords which should be kept
			if test -r "${config.users.root.stagingDirectory}/${target}" ; then
				expr="$(sed -nE '/_PASSWORD=/{s/^[[:space:]]*([^=]*)=(.*)/\/\1=\/s|=.*|=\2|;/;p;}' "${config.users.root.stagingDirectory}/${target}")"
				sed "$expr" ${source} > ${target}
			else
				cp ${source} ${target}
			fi
		'';

	in lib.mkIf (config.environment.loginHook != {} || config.environment.logoutHook != {}) {

		assertions = [
			(unknownFragmentAssertion "loginHook" config.environment.loginHook)
			(unknownFragmentAssertion "logoutHook" config.environment.logoutHook)
		];

		system.activationScripts.hooks = lib.stringAfter [ "staging" ] (''
			storeHeading 'Updating login and logout hook scripts'

			requireCommands activate-staging activate-root

			${preservePasswords loginHook "login-hook.sh"}
			${preservePasswords logoutHook "logout-hook.sh"}

			makeFile 700 "${config.users.root.stagingDirectory}/login-hook.sh" login-hook.sh
			makeFile 700 "${config.users.root.stagingDirectory}/logout-hook.sh" logout-hook.sh

		'' + lib.optionalString pkgs.stdenv.isDarwin ''

			makeDir 700 "${config.users.root.stagingDirectory}/Library/Preferences"
			makeFile 644 "${config.users.root.stagingDirectory}/Library/Preferences/com.apple.loginwindow.plist" ${./hooks-loginwindow.plist}
		'');

		system.activationScripts.root.deps = [ "hooks" ];

		environment.patches = lib.mkIf pkgs.stdenv.isLinux [
			./hooks-lightdm.patch
		];
	};
}
