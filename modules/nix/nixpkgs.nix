{ config, lib, ... }: {

	options.nixpkgs = {

		pkgs = lib.mkOption {
			type = lib.types.pkgs;
			example = lib.literalExpression "import <nixpkgs> {}";
			defaultText = lib.literalMD "The `legacyPackages` set of `config.nixpkgs.input`, with `config.nixpkgs.overlays` applied.";
			description = "If set, the pkgs argument to all modules is the value of this option.";
		};
		overlays = lib.mkOption {
			type = lib.types.listOf lib.types.anything;
			example = lib.literalExpression "[(final: prev: { texlive = final.texliveSmall; })]";
			default = [];
			description = "List of overlays to apply to Nixpkgs.";
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

	config = {

		# construct the final nixpkgs by extending the input with configured overlays
		# to avoid infinite recursion, so we must disallow usage of the `final` package set
		nixpkgs.pkgs = lib.mkOptionDefault (let
			pkgs = config.nixpkgs.input.legacyPackages.${config.nixpkgs.system};
			overlay = _: _: (lib.composeManyExtensions config.nixpkgs.overlays) null pkgs;
		in pkgs.extend overlay);

		# build package at rebuild-script runtime instead of at build-time
		# use when a package is only needed under conditions that are checked at runtime
		nixpkgs.overlays = [ (final: prev: rec {
			lazyBuild = pkg: let
				drv = builtins.unsafeDiscardOutputDependency pkg.drvPath;
			in "$(nix build --quiet --no-link --print-out-paths --no-warn-dirty ${drv}^out)";

			lazyCallPackage = path: args: lazyBuild (prev.callPackage path args);
		})];

		_module.args.pkgs = config.nixpkgs.pkgs;
	};
}
