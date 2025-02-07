{ config, lib, pkgs, options, ... }: {

	options = {

		system.build = lib.mkOption {
			internal = true;
			type = lib.types.attrsOf lib.types.unspecified;
			description = "Attribute set of derivations for system setup.";
		};
		system.activationScripts = lib.mkOption {
			type = lib.types.attrsOf (lib.types.either
				lib.types.str
				(lib.types.submodule { options = {
					deps = lib.mkOption {
						type = lib.types.listOf lib.types.str;
						default = [];
						description = "Dependencies after which the script can run.";
					};
					text = lib.mkOption {
						type = lib.types.lines;
						description = "Activation script text.";
					};
				};})
			);
			default = {};
			description = "A set of idempotent shell script fragments to build the system configuration.";
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

	config.system.build.activate = pkgs.writeTextFile {
		name = "base-activate";
		executable = true;
		text = let

			assertions = lib.pipe config.assertions [
				(lib.filter (x: !x.assertion))
				(map (x: "printError '• ${x.message}'"))
				(x: if x == [] then [] else ([
					"# print assertions"
					"printError 'Failed assertions while evaluating the configuration:'"
				] ++ x ++ [
					"exit 1"
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
				# warn when running on NixOS
				if test -r /etc/os-release ; then
					# shellcheck disable=SC1091
					. /etc/os-release
					if test "$ID" = nixos ; then
						printWarning 'Execution on NixOS installations is not recommended'
					fi
				fi
				# transition to a temporary directory
				tmpdir=$(mktemp -d -t "rebuild$($isDarwin || echo .XXXXXXXX)")
				# shellcheck disable=SC2064
				trap "rm -rf \"$tmpdir\"" EXIT HUP INT TERM QUIT
				cd "$tmpdir"
				unset tmpdir
			'';

			scripts = lib.pipe config.system.activationScripts [
				(lib.mapAttrs (_: v: if lib.isString v then lib.noDepEntry v else v))
				(lib.mapAttrs (n: v: v // { text = ''
					# ${n}
					${v.text}
				'';}))
				# dependency resolution magic from NixOS’ activation-script.nix
				(x: lib.textClosureMap lib.id x (lib.attrNames x))
			];

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
			${scripts}
		'';
		checkPhase = ''
			${pkgs.stdenv.shellDryRun} "$target"
			${lib.getExe pkgs.shellcheck} "$target"
		'';
	};

	config.system.build.manual = (pkgs.nixosOptionsDoc { inherit options; }).optionsCommonMark;
}
