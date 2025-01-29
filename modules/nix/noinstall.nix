{ config, lib, ... }: {

	# the nix activation script is used as a dependency even if we don’t install Nix
	config.system.activationScripts.nix = lib.mkIf (!config.nix.enable) "";
}
