{ config, lib, pkgs, ... }: {

	options.nix.settings = {

		builders = lib.mkOption {
			type = lib.types.listOf lib.types.singleLineStr;
			default = [];
			description = "Build machine entries for remote building of Nix derivations. See the Nix manual for the format of such entries.";
		};
		trusted-substituters = lib.mkOption {
			type = lib.types.listOf lib.types.singleLineStr;
			default = [];
			example = [ "https://cache.nixos.org/" ];
			description = "List of binary cache URLs that non-root users can use.";
		};
		trusted-public-keys = lib.mkOption {
			type = lib.types.listOf lib.types.singleLineStr;
			default = [];
			example = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
			description = "List of public keys used to sign binary caches.";
		};
	};

	config.nix.config = let

		cfg = config.nix.settings;

		defaultOptions = [
			"experimental-features = nix-command flakes"
			"use-xdg-base-directories = true"
			""
			"build-users-group = ${config.users.users._nix.group}"
			"keep-build-log = false"
			"keep-derivations = false"
			"sandbox = relaxed"
		];

		builderOptions = lib.optionals (config.nix.settings.builders != []) [
			(if lib.any (builder: lib.hasPrefix "builder-linux" builder) cfg.builders then
				"\n# the Linux builder VM has to be started manually on port 33022"
			else
				"")
			"builders = ${lib.concatStringsSep " ; " cfg.builders}"
			"builders-use-substitutes = true"
		];

		substituterOptions = lib.optionals (cfg.trusted-substituters != [] || cfg.trusted-public-keys != []) [
			""
		] ++ lib.optionals (cfg.trusted-substituters != []) [
			"trusted-substituters = ${lib.concatStringsSep " " cfg.trusted-substituters}"
		] ++ lib.optionals (cfg.trusted-public-keys != []) [
			"trusted-public-keys = ${lib.concatStringsSep " " cfg.trusted-public-keys}"
		];

	in lib.concatLines (defaultOptions ++ builderOptions ++ substituterOptions);
}
