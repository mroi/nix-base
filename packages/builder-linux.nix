# launch a NixOS Linux VM as a builder for Linux derivations on Darwin
{ system, path, binfmt ? false }:

# The necessary packages should be in the Nix binary cache, but sometimes the local store
# needs to be populated using: nix build --no-link nixpkgs/<commit>#darwin.linux-builder

let nixos = import "${path}/nixos" {

	configuration = { lib, modulesPath, ... }: {
		imports = [ "${modulesPath}/profiles/nix-builder-vm.nix" ];
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
		nixpkgs.hostPlatform = builtins.replaceStrings [ "darwin" ] [ "linux" ] system;
		boot.binfmt.emulatedSystems = if binfmt then [ "aarch64-linux" ] else [];
	};

	system = null;
};

in nixos.config.system.build.vm
