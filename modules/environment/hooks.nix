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
	
		knownFragments = [];

		unknownFragmentAssertion = name: set:
			let unknownFragments = lib.subtractLists knownFragments (lib.attrNames set);
			in {
				assertion = unknownFragments == [];
				message = "Unknown entry in ${name}: ${lib.concatStringsSep " " unknownFragments}";
			};

		stripTabs = text: let
			hasTabs = lines: lib.all (lib.hasPrefix "\t") (lib.take 1 lines);
			stripOneTab = lines: map (lib.removePrefix "\t") lines;
			stripMaxTabs = lines: if (hasTabs lines) then (stripMaxTabs (stripOneTab lines)) else lines;
		in lib.pipe text [
			(lib.splitString "\n")
			stripMaxTabs
			lib.concatLines
			(lib.removeSuffix "\n")
		];

		loginHook = pkgs.writeText "login-hook.sh" (lib.concatLines [
			"#!/bin/sh -e"
			""
			"PATH=/bin:/sbin:/usr/bin:/usr/sbin"
		] + lib.concatMapStrings (s: if s == "" then "" else "\n" + s) [
		]);

		logoutHook = pkgs.writeText "logout-hook.sh" (lib.concatLines [
			"#!/bin/sh -e"
			""
			"PATH=/bin:/sbin:/usr/bin:/usr/sbin"
		] + lib.concatMapStrings (s: if s == "" then "" else "\n" + s) [
		]);

		preservePasswords = source: target: ''
			# existing ${target} in staging may contain passwords which should be kept
			if test -r "${config.users.root.stagingDirectory}/${target}" ; then
				expr="$(sed -nE '/_PASSWORD=/{s/^[[:space:]]*([^=]*)=(.*)/\/\1=\/s|=.*|=\2|;/;p;}' "${config.users.root.stagingDirectory}/${target}")"
				sed "$expr" ${source} > ${target}
			else
				cp ${source} ${target}
			fi
		'';

	in {

		assertions = [
			(unknownFragmentAssertion "loginHook" config.environment.loginHook)
			(unknownFragmentAssertion "logoutHook" config.environment.logoutHook)
		];

		system.activationScripts.hooks = lib.stringAfter [ "staging" ] ''
			storeHeading

			${preservePasswords loginHook "login-hook.sh"}
			${preservePasswords logoutHook "logout-hook.sh"}

			${pkgs.stdenv.shellDryRun} login-hook.sh
			${pkgs.stdenv.shellDryRun} logout-hook.sh
			${lib.getExe pkgs.shellcheck} login-hook.sh logout-hook.sh

			updateFile 700 "${config.users.root.stagingDirectory}/login-hook.sh" login-hook.sh
			updateFile 700 "${config.users.root.stagingDirectory}/logout-hook.sh" logout-hook.sh
		'';

		system.activationScripts.root.deps = [ "hooks" ];
	};
}
