{ config, lib, pkgs, ... }: {

	options.security.password = {
		yescrypt.rounds = lib.mkOption {
			type = lib.types.nullOr lib.types.int;
			default = 11;
			description = "The number of hashing rounds for the yescrypt password hash.";
		};
	};

	config = let

		yescryptApplicable = (config.security.password.yescrypt.rounds != null) && pkgs.stdenv.isLinux;
		yescryptPatch = pkgs.runCommand "password-crypt-rounds.patch" {} ''
			substitute ${./password-crypt-rounds.patch} $out \
				--subst-var-by ROUNDS "${toString config.security.password.yescrypt.rounds}"
		'';

	in lib.mkIf config.system.systemwideSetup {

		environment.patches = lib.optionals yescryptApplicable [ yescryptPatch ];
	};
}
