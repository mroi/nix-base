{ config, lib, pkgs, ... }: {

	options = {
		system.build = lib.mkOption {
			internal = true;
			type = lib.types.attrsOf lib.types.unspecified;
			description = lib.mdDoc "Attribute set of derivations for system setup.";
		};
		system.activationScripts = lib.mkOption {
			type = lib.types.attrsOf (lib.types.either
				lib.types.str
				(lib.types.submodule { options = {
					deps = lib.mkOption {
						type = lib.types.listOf lib.types.str;
						default = [];
						description = lib.mdDoc "Dependencies after which the script can run.";
					};
					text = lib.mkOption {
						type = lib.types.lines;
						description = lib.mdDoc "Activation script text.";
					};
				};})
			);
			default = {};
			description = lib.mdDoc "A set of idempotent shell script fragments to build the system configuration.";
		};
		assertions = lib.mkOption {
			internal = true;
			type = lib.types.listOf lib.types.unspecified;
			default = [];
			description = lib.mdDoc "Conditions that must hold during evaluation of the configuration.";
		};
		warnings = lib.mkOption {
			internal = true;
			type = lib.types.listOf lib.types.str;
			default = [];
			description = lib.mdDoc "Warnings collected during evaluation of the configuration.";
		};
	};

	config.system.build.toplevel = pkgs.writeTextFile {
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
			${lib.fileContents ./utils.sh}
			${assertions}
			${warnings}
			${scripts}
		'';
		checkPhase = ''
			${pkgs.stdenv.shellDryRun} "$target"
			${lib.getExe pkgs.shellcheck} "$target"
		'';
	};
}
