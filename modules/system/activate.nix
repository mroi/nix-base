{ config, lib, pkgs, ... }: {

	options = {
		system.build = lib.mkOption {
			internal = true;
			type = lib.types.attrsOf lib.types.unspecified;
			description = lib.mdDoc "Attribute set of derivations for system setup.";
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

		in ''#!/bin/sh -e
			# shellcheck disable=SC2317
			export PATH=/usr/bin:/bin:/usr/sbin:/sbin
			${lib.fileContents ./utils.sh}
			${assertions}
			${warnings}
		'';
		checkPhase = ''
			${pkgs.stdenv.shellDryRun} "$target"
			${lib.getExe pkgs.shellcheck} "$target"
		'';
	};
}
