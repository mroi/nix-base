{ config, lib, pkgs, options, ... }: {

	options.system = {

		systemwideSetup = lib.mkEnableOption "option defaults performing systemwide setup";
	};

	config = let

		isSystemwide = config.system.systemwideSetup;
		isLocal = ! config.system.systemwideSetup;
		localNullOr = default: if isLocal then null else default;

	in lib.mkDefault {

		system.systemwideSetup = true;

		# mute these settings for local-only setups
		security.password.yescrypt.rounds = localNullOr options.security.password.yescrypt.rounds.default;
		services.openssh.enable = localNullOr options.services.openssh.enable.default;
		system.packages = localNullOr options.system.packages.default;
		users.directory.authentication.searchPolicy = localNullOr options.users.directory.authentication.searchPolicy.default;
		users.directory.information.searchPolicy = localNullOr options.users.directory.information.searchPolicy.default;
		users.root.stagingDirectory = localNullOr options.users.root.stagingDirectory.default;

		# reconfigure depending on systemwide option
		environment.flatpak = if isLocal && pkgs.stdenv.isLinux then "user" else options.environment.flatpak.default;
		networking.firewall.enable = isSystemwide && pkgs.stdenv.isDarwin;
		nix.enable = isSystemwide;
		security.sudo.touchId = isSystemwide && pkgs.stdenv.isDarwin;
		security.sudo.adminFlagFile = !(isSystemwide && pkgs.stdenv.isLinux);
		users.guest.enable = isSystemwide;
	};
}
