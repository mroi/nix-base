# launch a NixOS Linux VM as a builder for Linux derivations on Darwin
{ stdenvNoCC, path, binfmt ? false }:

let nixos = import "${path}/nixos" {

	configuration = { config, lib, modulesPath, ... }: {

		imports = [ "${modulesPath}/profiles/nix-builder-vm.nix" ];

		virtualisation = let hostPkgs = import path { inherit (stdenvNoCC.hostPlatform) system; }; in {
			host.pkgs = hostPkgs;

			darwin-builder = {
				diskSize = 128 * 1024;
				hostPort = 33022;
			};

			# SSH access only from localhost
			forwardPorts = lib.mkForce [{
				from = "host";
				host.address = "127.0.0.1";
				host.port = config.virtualisation.darwin-builder.hostPort;
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

		nixpkgs.hostPlatform = builtins.replaceStrings [ "darwin" ] [ "linux" ] stdenvNoCC.hostPlatform.system;
		boot.binfmt.emulatedSystems = lib.mkIf binfmt (builtins.getAttr stdenvNoCC.hostPlatform.parsed.cpu.name {
			aarch64 = [ "x86_64-linux" ];
			x86_64 = [ "aarch64-linux" ];
		});
	};

	system = null;
};

in nixos.config.system.build.vm
