{ config, lib, ... }: {

	options.environment.shared = {
		enable = lib.mkEnableOption "folder with common files" // { default = true; };
	};
}
