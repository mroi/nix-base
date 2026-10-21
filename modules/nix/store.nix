{ config, lib, ... }: {

	config = lib.mkIf config.nix.enable {

		system.cleanupScripts.nix = lib.stringAfter [ "volumes" "profile" ] ''
			storeHeading 'Cleaning the Nix store'

			trace nix store gc || true
			trace nix store optimise || true
			trace nix store verify --all || true
		'';
	};
}
