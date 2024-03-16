# launch a NixOS Linux VM as a builder for Linux derivations on Darwin
{ system, path, binfmt ? false }:

let nixos = import "${path}/nixos" {
	configuration = { lib, modulesPath, ... }: {
		imports = [ "${modulesPath}/profiles/macos-builder.nix"	];
		virtualisation = {
			host.pkgs = import path { inherit system; };
			forwardPorts = lib.mkForce [{
				from = "host";
				host.address = "127.0.0.1";
				host.port = 33022;
				guest.port = 22;
			}];
			sharedDirectories.keys.source = lib.mkForce "/nix/var/ssh";
		};
		boot.binfmt.emulatedSystems = if binfmt then [ "aarch64-linux" ] else [];
	};
	system = builtins.replaceStrings [ "darwin" ] [ "linux" ] system;
};
in nixos.config.system.build.vm
