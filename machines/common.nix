{ lib, pkgs, options, ... }: {

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
	nixpkgs.pkgs = options.nixpkgs.pkgs.default.extend (final: prev: {
		nix = if final.stdenv.isDarwin then
			prev.nix.overrideAttrs {
				patches = builtins.fetchurl {
					url = "https://github.com/NixOS/nix/pull/12570.diff";
					sha256 = "1ad46a11n1i0anhcjzdxb7n34jpn98z0h06vkc1rspn6r6awlyxg";
				};
			}
		else prev.nix;
	});

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
