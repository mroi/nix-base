{ config, lib, pkgs, ... }: {

	options.system = {

		systemwideSetup = lib.mkEnableOption "option defaults performing systemwide setup" // {
			default = true;
		};
	};

	config = lib.mkIf (!config.system.systemwideSetup) (lib.mkDefault {

		# disable changes with system-level effects
		security.password.yescrypt.rounds = null;
		services.openssh.enable = null;
		system.packages = null;
		users.defaultScriptShell = null;
		users.directory.authentication.searchPolicy = null;
		users.directory.information.searchPolicy = null;
		users.root.stagingDirectory = null;
		users.shared.folder = null;

		# adapt configuration for non-systemwide setups
		environment.flatpak = if pkgs.stdenv.isLinux then "user" else "none";
		networking.firewall.enable = false;
		nix.enable = false;
		security.sudo.touchId = false;
		security.sudo.adminFlagFile = pkgs.stdenv.isLinux;
		services.unison.enable = false;
		users.guest.enable = false;
	});
}
