{ config, lib, ... }: let

	scriptOption = description: lib.mkOption {
		inherit description;
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
					description = "Script text.";
				};
			};})
		);
		default = {};
	};

	scriptBuild = command: scripts: lib.pipe scripts [
		(lib.mapAttrs (_: v: if lib.isString v then lib.noDepEntry v else v))
		(lib.mapAttrs (n: v: v // { text = ''
			# ${n}
			if checkArgs ${command}-${n} ${command} all ; then
				:
				${v.text}
			fi
		'';}))
		# dependency resolution magic from NixOS’ activation-script.nix
		(x: lib.textClosureMap lib.id x (lib.attrNames x))
	];

in {

	options.system.activationScripts = scriptOption "A set of idempotent shell script fragments to build the system configuration.";

	config.system.build.activate = scriptBuild "activate" config.system.activationScripts;
}
