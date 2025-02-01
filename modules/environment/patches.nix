{ config, lib, ... }: {

	options.environment.patches = lib.mkOption {
		type = lib.types.listOf lib.types.path;
		default = [];
		description = "Patches to be applied to the system.";
	};

	config = let

		patchStaging = "${config.users.root.stagingDirectory}/patches";

		patchApplyScript = patch: ''
			if test -f "${patchStaging}/${builtins.baseNameOf patch}" && ! cmp --quiet "${patch}" "${patchStaging}/${builtins.baseNameOf patch}" ; then
				# revert previous patch
				rootPatch=~root/patches/"${builtins.baseNameOf patch}"
				trace sudo patch --strip 0 --directory / --reverse --input "$rootPatch"
				rm "${patchStaging}/${builtins.baseNameOf patch}"
			fi
			if ! test -f "${patchStaging}/${builtins.baseNameOf patch}" ; then
				# print the patch if it is small (50 lines)
				if test "$(wc -l < "${patch}")" -lt 51 ; then
					flushHeading
					cat "${patch}"
				fi
				# apply patch
				trace sudo patch --strip 0 --directory / --input "${patch}"
				# add patch to staging directory
				makeDir 700 "${patchStaging}"
				cp "${patch}" "${patchStaging}/${builtins.baseNameOf patch}"
				chmod 644 "${patchStaging}/${builtins.baseNameOf patch}"
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

	in {

		assertions = [{
			assertion = lib.allUnique (map builtins.baseNameOf config.environment.patches);
			message = "All patch files must have a unique name.";
		}];

		system.activationScripts.patches = lib.stringAfter [ "staging" ] ''
			storeHeading 'Managing patches for system files'

			patches="${lib.concatLines (map builtins.baseNameOf config.environment.patches)}"

			# revert patches not in requested list
			for patch in "${patchStaging}/"* ; do
				if test -f "$patch" && ! hasLine "$patches" "''${patch##*/}" ; then
					${patchRevertScript "$patch"}
				fi
			done

			# apply requested patches
			${lib.concatLines (map patchApplyScript config.environment.patches)}
		'';

		system.activationScripts.root.deps = [ "patches" ];
	};
}
