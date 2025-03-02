{ config, lib, ... }: {

	config = lib.mkIf config.nix.enable {

		system.cleanupScripts.nix = lib.stringAfter [ "volumes" "profile" ] ''
			storeHeading 'Cleaning the Nix store'

			trace nix store gc
			trace nix store optimise
			trace nix store verify --all || true
		'';
	};
}
