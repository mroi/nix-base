{ lib, ... }: {

	options.system = {

		systemwideSetup = lib.mkEnableOption "option defaults performing systemwide setup";
	};

	config.system.systemwideSetup = lib.mkDefault true;
}
