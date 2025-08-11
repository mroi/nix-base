# launch a NixOS Linux VM as a builder for Linux derivations on Darwin
{ system, path, binfmt ? false }:

# The necessary packages should be in the Nix binary cache, but sometimes the local store
# needs to be populated using: nix build --no-link nixpkgs/<commit>#darwin.linux-builder

let nixos = import "${path}/nixos" {

	configuration = { lib, modulesPath, ... }: {

		imports = [ "${modulesPath}/profiles/nix-builder-vm.nix" ];

		virtualisation = let hostPkgs = import path { inherit system; }; in {
			host.pkgs = hostPkgs;
			diskSize = lib.mkForce (128 * 1024);

			# SSH access
			forwardPorts = lib.mkForce [{
				from = "host";
				host.address = "127.0.0.1";
				host.port = 33022;
				guest.port = 22;
			}];
			sharedDirectories.keys.source = lib.mkForce "/nix/var/ssh";

			# exclude QEMU disk image from Time Machine backups
			qemu.package = hostPkgs.runCommand hostPkgs.qemu.name {} ''
				mkdir -p $out/bin
				ln -s ${hostPkgs.qemu}/bin/* $out/bin/
				rm $out/bin/qemu-img
				cat <<- 'EOF' > $out/bin/qemu-img
					#!/bin/sh -e
					${hostPkgs.qemu}/bin/qemu-img "$@"
					for arg ; do
						if test -w "$arg" ; then tmutil addexclusion "$arg" ; fi
					done
				EOF
				chmod a+x $out/bin/qemu-img
			'';
		};

		nixpkgs.hostPlatform = builtins.replaceStrings [ "darwin" ] [ "linux" ] system;
		boot.binfmt.emulatedSystems = if binfmt then builtins.getAttr system {
			aarch64-linux = [ "x86_64-linux" ];
			x86_64-linux = [ "aarch64-linux" ];
		} else [];
	};

	system = null;
};

in nixos.config.system.build.vm
