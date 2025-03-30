{ config, lib, ... }: {

	options.programs.develop.enable = lib.mkEnableOption "developer programs";

	config = lib.mkIf config.programs.develop.enable {

		programs.gitup.enable = true;
	};
}
