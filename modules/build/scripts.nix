{ config, lib, ... }: let

	fragments = [
		"apps"
		"directory"
		"firewall"
		"groups"
		"hooks"
		"nix"
		"packages"
		"patches"
		"profile"
		"root"
		"rootpaths"
		"services"
		"sip"
		"ssh"
		"staging"
		"users"
		"volumes"
	];

	unknownFragmentAssertion = name: list:
		let unknownFragments = lib.subtractLists fragments list;
		in {
			assertion = unknownFragments == [];
			message = "Unknown entry in ${name}: ${lib.concatStringsSep " " unknownFragments}";
		};

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
		# remove dangling dependencies
		(lib.mapAttrs (_: v: v // { deps = lib.intersectLists v.deps (lib.attrNames scripts); }))
		# discard script fragments with no actual code
		(lib.mapAttrs (_: v: v // { text = lib.optionalString (lib.match "[ \t\n]*storeHeading [^\n]*[ \t\n]*" v.text == null) v.text; }))
		# construct command line subcommand arguments
		(lib.mapAttrs (n: v: v // { text = lib.optionalString (v.text != "") ''
			# ${n}
			if checkArgs ${command}-${n} ${command} all ; then
				${v.text}
			fi
		'';}))
		# dependency resolution magic from NixOS’ activation-script.nix
		(x: lib.textClosureMap lib.id x (lib.attrNames x))
	];

in {

	config.assertions = let
		fragmentNames = lib.attrNames;
		dependencies = x: lib.pipe x [
			lib.attrValues
			(lib.filter lib.isAttrs)
			(lib.catAttrs "deps")
			lib.flatten
		];
	in [
		(unknownFragmentAssertion "activationScripts" (fragmentNames config.system.activationScripts))
		(unknownFragmentAssertion "updateScripts" (fragmentNames config.system.updateScripts))
		(unknownFragmentAssertion "cleanupScripts" (fragmentNames config.system.cleanupScripts))
		(unknownFragmentAssertion "activationScript dependencies" (dependencies config.system.activationScripts))
		(unknownFragmentAssertion "updateScript dependencies" (dependencies config.system.updateScripts))
		(unknownFragmentAssertion "cleanupScript dependencies" (dependencies config.system.cleanupScripts))
	];

	options.system.activationScripts = scriptOption "A set of idempotent shell script fragments to build the system configuration.";
	options.system.updateScripts = scriptOption "A set of shell script fragments to update the system.";
	options.system.cleanupScripts = scriptOption "A set of shell script fragments to maintain and clean the system.";

	config.system.build.activate = scriptBuild "activate" config.system.activationScripts;
	config.system.build.update = scriptBuild "update" config.system.updateScripts;
	config.system.build.cleanup = scriptBuild "clean" config.system.cleanupScripts;
}
