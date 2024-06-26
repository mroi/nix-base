{ config, lib, ... }: {

	options.nixpkgs = {

		pkgs = lib.mkOption {
			type = lib.types.pkgs;
			example = lib.literalExpression "import <nixpkgs> {}";
			default = config.nixpkgs.input.legacyPackages.${config.nixpkgs.system};
			defaultText = lib.literalMD "The `legacyPackages` set of `config.nixpkgs.input`.";
			description = "If set, the pkgs argument to all modules is the value of this option.";
		};
		system = lib.mkOption {
			type = lib.types.str;
			example = "x86_64-darwin";
			description = "The Nix platform under which Nixpkgs is evaluated.";
		};
		input = lib.mkOption {
			type = lib.types.package;
			defaultText = lib.literalMD "The `nixpkgs` flake input.";
			description = "The input from which the Nixpkgs package set is derived.";
		};
	};

	config._module.args.pkgs = config.nixpkgs.pkgs;
}
