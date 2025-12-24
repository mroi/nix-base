{
	description = "custom Nix packages";
	outputs = { self, nixpkgs }: let

		packages = {
			aarch64-darwin = [
				"arq-restore" "bitwarden-decrypt" "blender" "builder-linux" "dash" "doom"
				"doom3" "fish" "gitup" "hires" "imageoptim" "inkscape" "lyx" "nix" "ollama"
				"outlookmsg" "quake" "run-linux" "texlive" "unison" "veusz" "vice"
				"vmware-vmx"
			];
			x86_64-darwin = [
				"arq-restore" "bitwarden-decrypt" "builder-linux" "dash" "doom" "doom3"
				"fish" "gitup" "hires" "imageoptim" "lyx" "nix" "ollama" "outlookmsg"
				"quake" "run-linux" "texlive" "unison" "veusz" "vmware-vmx"
			];
			aarch64-linux = [
				"bitwarden-decrypt" "fish" "nix" "ollama" "outlookmsg" "texlive" "unison"
				"vmware-vmx"
			];
			x86_64-linux = [
				"bitwarden-decrypt" "fish" "nix" "ollama" "outlookmsg" "texlive" "unison"
				"vmware-vmx"
			];
		};

		lib = nixpkgs.lib;
		forAll = list: f: lib.genAttrs list f;
		callPackage = system: lib.callPackageWith nixpkgs.legacyPackages.${system};

		systems = builtins.attrNames packages;
		machines = lib.pipe ./machines [
			builtins.readDir
			(lib.filterAttrs (file: type: type == "directory"))
			builtins.attrNames
		];

	in {

		packages = forAll systems (system:
			forAll packages.${system} (package:
				callPackage system ./packages/${package}.nix {}
			)
		);
		overlays.default = final: prev: (
			forAll (lib.flatten lib.attrValues packages) (package:
				final.callPackage ./packages/${package}.nix {}
			)
		);
		legacyPackages = forAll systems (system: {
			cross = import ./cross.nix { inherit system nixpkgs; };
		});

		apps = forAll [ "aarch64-darwin" "x86_64-darwin" ] (system: {
			builder-linux = {
				type = "app";
				program = "${self.packages.${system}.builder-linux}/bin/run-nixos-vm";
				meta.description = "NixOS Linux VM as a builder for Linux derivations on Darwin";
			};
			run-linux = {
				type = "app";
				program = "${self.packages.${system}.run-linux}";
				meta.description = "ephemeral VM to run Linux commands on macOS";
			};
		});

		baseModules = import ./modules/all.nix;
		baseConfigurations = forAll machines (machine:
			lib.evalModules {
				modules = [ ./machines/${machine}/configuration.nix ]
					++ (builtins.attrValues self.baseModules)
					++ [ { nixpkgs.input = lib.mkDefault nixpkgs; } ];
				class = "base";
			}
		);

		checks = forAll systems (system:
			(lib.pipe (forAll packages.${system} lib.id) [
				(lib.mapAttrs (name: value: self.packages.${system}.${name}))
			]) // (lib.pipe (forAll machines lib.id) [
				(lib.mapAttrs (name: value: self.baseConfigurations.${name}.config))
				(lib.filterAttrs (name: value: value.nixpkgs.system == system))
				(lib.concatMapAttrs (name: value: {
					"${name}-rebuild" = value.system.build.rebuild;
					"${name}-portable" = value.system.build.portable;
					"${name}-manual" = value.system.build.manual;
				}))
			])
		);

		templates = {
			default = self.templates.shell;
			shell = {
				path = ./templates/shell;
				description = "Default shell skeleton";
			};
			tex = {
				path = ./templates/tex;
				description = "Example LaTeX shell";
			};
		};
	};
}
