{ lib, pkgs, ... }: {

	system.defaultCommands = [ "activate" ];

	system.packages = lib.mkIf pkgs.stdenv.isLinux [
		"patch"
	];

	environment.profile = [
		"nix-base#nix"
		"nix-base#fish"
		"nixpkgs#micro"
	];

	# patch from https://github.com/NixOS/nix/pull/12570 to fix sandbox exceeded error
	nixpkgs.overlays = [ (final: prev: {
		nix = prev.nix.overrideAttrs (lib.optionalAttrs prev.stdenv.isDarwin {
			patches = assert prev.nix.version == "2.24.12"; builtins.fetchurl {
				url = "https://github.com/NixOS/nix/pull/12570.diff";
				sha256 = "1ppaml5nbi2hhn9sjczgm39s3ag0szwf2gp14yl8dv9lhv49cc2p";
			};
		});
	})];

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
