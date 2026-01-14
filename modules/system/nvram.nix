{ config, lib, pkgs, ... }: {

	options.system.nvram = lib.mkOption {
		type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
		default = {};
		description = "Set system boot variables in non-volatile RAM.";
	};

	config = let

		nvramVarsToCreate = lib.attrsToList (lib.filterAttrs (n: v: v != null) config.system.nvram);
		nvramVarsToDelete = lib.attrsToList (lib.filterAttrs (n: v: v == null) config.system.nvram);

		createNvramVarScript = var: ''
			if test "$(nvram '${var.name}' | cut -f2-)" != '${var.value}' ; then
				trace sudo nvram '${var.name}=${var.value}'
			fi
		'';
		deleteNvramVarScript = var: ''
			if nvram '${var.name}' > /dev/null 2>&1 ; then
				trace sudo nvram -d '${var.name}'
			fi
		'';

	in {

		assertions = [{
			assertion = config.system.nvram != {} -> pkgs.stdenv.isDarwin;
			message = "NVRAM variables are only supported on Darwin";
		}];

		system.activationScripts.nvram = ''
			storeHeading 'Set NVRAM boot variables'

			${lib.concatLines (map deleteNvramVarScript nvramVarsToDelete)}
			${lib.concatLines (map createNvramVarScript nvramVarsToCreate)}
		'';
	};
}
