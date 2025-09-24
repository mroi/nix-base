{ config, lib, pkgs, options, ... }: {

	options = {

		system.build = lib.mkOption {
			internal = true;
			type = lib.types.attrsOf lib.types.unspecified;
			description = "Attribute set of derivations for system setup.";
		};
		system.defaultCommands = lib.mkOption {
			type = lib.types.listOf lib.types.str;
			default = [ "activate" ];
			description = "The default commands to run when no arguments are passed on the command line.";
		};

		assertions = lib.mkOption {
			internal = true;
			type = lib.types.listOf lib.types.unspecified;
			default = [];
			description = "Conditions that must hold during evaluation of the configuration.";
		};
		warnings = lib.mkOption {
			internal = true;
			type = lib.types.listOf lib.types.str;
			default = [];
			description = "Warnings collected during evaluation of the configuration.";
		};
	};

	config.system.build.rebuild = pkgs.writeTextFile {
		name = "rebuild";
		executable = true;
		text = let

			assertions = lib.pipe config.assertions [
				(lib.filter (x: !x.assertion))
				(map (x: "printError '• ${x.message}'"))
				(x: if x == [] then [] else ([
					"# print assertions"
					"printError 'Failed assertions while evaluating the configuration:'"
				] ++ x ++ [
					"exit 64  # EX_USAGE"
				]))
				lib.concatLines
			];

			warnings = lib.pipe config.warnings [
				(map (x: "printWarning '• ${x}'"))
				(x: if x == [] then [] else ([
					"# print warnings"
					"printWarning 'Warnings while evaluating the configuration:'"
				] ++ x))
				lib.concatLines
			];

			setup = ''
				cdTemporaryDirectory

				# warn when running on NixOS
				if test -r /etc/os-release ; then
					# shellcheck disable=SC1091
					. /etc/os-release
					if test "$ID" = nixos ; then
						printWarning 'Execution on NixOS installations is not recommended'
					fi
				fi
			'' + lib.optionalString pkgs.stdenv.isDarwin ''
				# error when running without full disk access
				if test -d ~/Library/Application\ Support/com.apple.TCC -a ! -r ~/Library/Application\ Support/com.apple.TCC ; then
					fatalError 'Rebuild requires full disk access'
				fi
			'';

		in ''#!/bin/sh -e
			# shellcheck disable=SC2317
			export PATH=/usr/bin:/bin:/usr/sbin:/sbin
			isLinux=${lib.boolToString pkgs.stdenv.isLinux}
			isDarwin=${lib.boolToString pkgs.stdenv.isDarwin}
			isx86_64=${lib.boolToString pkgs.stdenv.isx86_64}
			isAarch64=${lib.boolToString pkgs.stdenv.isAarch64}
			${lib.fileContents ./state.sh}
			${lib.fileContents ./utils.sh}
			${assertions}
			${warnings}
			${setup}
			${config.system.build.activate}
			${config.system.build.update}
			${config.system.build.cleanup}
		'';
		checkPhase = ''
			${pkgs.stdenv.shellDryRun} "$out"
			${lib.getExe pkgs.shellcheck} "$out"
		'';
	};

	config.system.build.manual = (pkgs.nixosOptionsDoc { inherit options; }).optionsCommonMark;
}
