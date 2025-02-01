{ config, lib, ... }: {

	options.environment.patches = lib.mkOption {
		type = lib.types.listOf (lib.types.either
			lib.types.path
			(lib.types.submodule { options = {
				patch = lib.mkOption {
					type = lib.types.path;
					description = "The patch file.";
				};
				postCommand = lib.mkOption {
					type = lib.types.lines;
					default = "";
					description = "A shell script to run whenever the patch is applied.";
				};
			};})
		);
		default = [];
		description = "Patches to be applied to the system.";
	};

	config = let

		patches = lib.pipe config.environment.patches [
			(map (x: if (lib.isPath x || lib.isString x || lib.isDerivation x) then { patch = x; postCommand = ""; } else x))
			(map (x: { file = x.patch; name = builtins.baseNameOf x.patch; post = x.postCommand; }))
			(map (x: if lib.isStorePath x.file then x // { name = lib.substring 33 (-1) x.name; } else x))
		];
		patchNames = map (lib.getAttr "name") patches;

		patchStaging = "${config.users.root.stagingDirectory}/patches";

		patchApplyScript = patch: let staged = "${patchStaging}/${patch.name}"; in ''
			if test -f "${staged}" && ! cmp --quiet "${patch.file}" "${staged}" ; then
				# revert previous patch
				rootPatch=~root/patches/"${patch.name}"
				trace sudo patch --strip 0 --directory / --reverse --input "$rootPatch"
				rm "${staged}"
			fi
			if ! test -f "${staged}" ; then
				# print the patch if it is small (50 lines)
				if test "$(wc -l < "${patch.file}")" -lt 51 ; then
					flushHeading
					cat "${patch.file}"
				fi
				# apply patch
				trace sudo patch --strip 0 --directory / --input "${patch.file}"
				# add patch to staging directory
				makeDir 700 "${patchStaging}"
				cp "${patch.file}" "${staged}"
				chmod 644 "${staged}"
				# run post command
				${patch.post}
			fi
		'';
		patchCheckScript = patch: ''
			if ! patch --dry-run --quiet --reverse --strip 0 --directory / --input "${patch.file}" 2> /dev/null ; then
				# reapply patch
				trace sudo patch --strip 0 --directory / --input "${patch.file}"
				# run post command
				${patch.post}
			fi
		'';
		patchRevertScript = patch: ''
			rootPatch=~root/patches/"$(basename "${patch}")"
			trace sudo patch --strip 0 --directory / --reverse --input "$rootPatch"
			trace sudo rm "$rootPatch"
			# remove from staging and possibly remove entire directory
			rm "${patch}"
			rmdir "${patchStaging}" 2> /dev/null || true
		'';

	in lib.mkIf config.system.systemwideSetup {

		assertions = [{
			assertion = lib.allUnique patchNames;
			message = "All patch files must have a unique name.";
		}];

		system.activationScripts.patches = lib.stringAfter [ "staging" ] ''
			storeHeading 'Managing patches for system files'

			patches="${lib.concatLines patchNames}"

			# revert patches not in requested list
			for patch in "${patchStaging}/"* ; do
				if test -f "$patch" && ! hasLine "$patches" "''${patch##*/}" ; then
					${patchRevertScript "$patch"}
				fi
			done

			# apply requested patches
			${lib.concatLines (map patchApplyScript patches)}

			# check all patches to be properly applied
			${lib.concatLines (map patchCheckScript patches)}
		'';

		system.activationScripts.root.deps = [ "patches" ];
	};
}
