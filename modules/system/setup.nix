{ lib, ... }: {

	options.system = {

		systemwideSetup = lib.mkEnableOption "Enable default options performing systemwide setup.";
	};

	config.system.systemwideSetup = lib.mkDefault true;
}
