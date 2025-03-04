{ lib, pkgs, ... }: {

	system.defaultCommands = [ "activate" ];

	environment.profile = [
		"nix-base#nix"
		"nix-base#fish"
		"nixpkgs#micro"
	];

	networking.firewall = lib.mkIf pkgs.stdenv.isDarwin {
		allow = [
			"/System/Library/CoreServices/UniversalControl.app/Contents/MacOS/UniversalControl"
			"/System/Library/PrivateFrameworks/ChronoCore.framework/Support/chronod"
			"/System/Library/PrivateFrameworks/IDS.framework/identityservicesd.app/Contents/MacOS/identityservicesd"
			"/usr/libexec/AirPlayXPCHelper"
			"/usr/libexec/audioclocksyncd"
			"/usr/libexec/rapportd"
			"/usr/libexec/sharingd"
		];
	};
}
