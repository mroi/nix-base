{ lib, pkgs, ... }: {

	options = {
		system.build = lib.mkOption {
			internal = true;
			type = lib.types.attrsOf lib.types.unspecified;
			description = lib.mdDoc "Attribute set of derivations for system setup.";
		};
	};

	config.system.build.toplevel = pkgs.writeTextFile {
		name = "base-activate";
		executable = true;
		text = ''#!/bin/sh -e
			export PATH=/usr/bin:/bin:/usr/sbin:/sbin
			${builtins.readFile ./utils.sh}
		'';
		checkPhase = ''
			${pkgs.stdenv.shellDryRun} "$target"
			${lib.getExe pkgs.shellcheck} "$target"
		'';
	};
}
