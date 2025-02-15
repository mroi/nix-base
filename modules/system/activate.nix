{ config, lib, ... }: {

	options.system.activationScripts = lib.mkOption {
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

	config.system.build.activate = lib.pipe config.system.activationScripts [
		(lib.mapAttrs (_: v: if lib.isString v then lib.noDepEntry v else v))
		(lib.mapAttrs (n: v: v // { text = ''
			# ${n}
			if checkArgs activate-${n} activate all ; then
				:
				${v.text}
			fi
		'';}))
		# dependency resolution magic from NixOS’ activation-script.nix
		(x: lib.textClosureMap lib.id x (lib.attrNames x))
	];
}
