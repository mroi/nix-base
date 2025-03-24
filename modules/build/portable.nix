{ config, lib, pkgs, ... }: {

	config.system.build.portable = pkgs.writeTextFile {
		name = "rebuild";
		executable = true;
		text = let

			tmpDir = "/tmp/rebuild-closure";
			rebuildClosure = pkgs.runCommand "rebuild-closure" {} ''
				# rewrite all store paths in the rebuild script
				sed -E '\|${builtins.storeDir}/[[:alnum:]]{32}|s|${builtins.storeDir}/|${tmpDir}/|g' ${config.system.build.rebuild} > rebuild
				chmod a+x rebuild
				tar --create --file=rebuild-closure.tar rebuild

				# collect the Nix files used by the rebuild script and append to the tar
				grep -E --only-matching '${builtins.storeDir}/[[:alnum:]._-]+' ${config.system.build.rebuild} | sort | uniq | while read -r store ; do
					# remove the Nix store dir prefix
					echo "''${store#${builtins.storeDir}/}"
				done | tar --append --file=rebuild-closure.tar --directory=${builtins.storeDir} --files-from=-

				# dump the resulting tar file as base64
				gzip -c rebuild-closure.tar | base64 > $out
			'';

			stripTabs = text: let
				hasTabs = lib.any (lib.hasPrefix "\t");
				stripOneTab = map (lib.removePrefix "\t");
				stripAllTabs = lines: if (hasTabs lines) then (stripAllTabs (stripOneTab lines)) else lines;
			in lib.pipe text [
				(lib.splitString "\n")
				stripAllTabs
				(lib.concatStringsSep "\n")
			];

		in stripTabs ''#!/bin/sh -e
			export PATH=/usr/bin:/bin:/usr/sbin:/sbin
			rm -rf ${tmpDir} ; mkdir ${tmpDir}
			trap 'rm -rf ${tmpDir}' EXIT HUP INT TERM QUIT
			base64 --decode << %EOF% | tar --extract --gunzip --directory=${tmpDir}
				${lib.fileContents rebuildClosure}
			%EOF%
			${tmpDir}/rebuild "$@"
		'';
		checkPhase = ''
			${pkgs.stdenv.shellDryRun} "$out"
			${lib.getExe pkgs.shellcheck} "$out"
		'';
	};
}
