{
	description = "custom Nix packages";
	outputs = { self, nixpkgs }: let
		systemPackages = {
			aarch64-darwin = [
				"arq-restore" "builder-linux" "fish" "gitup" "hires" "nix" "run-linux"
				"texlive" "unison" "unison-fsmonitor" "vmware-vmx"
			];
			x86_64-darwin = [
				"arq-restore" "builder-linux" "fish" "gitup" "hires" "nix" "run-linux"
				"texlive" "unison" "unison-fsmonitor" "vmware-vmx"
			];
			aarch64-linux = [
				"fish" "nix" "texlive" "unison"
			];
			x86_64-linux = [
				"fish" "nix" "texlive" "unison"
			];
		};

		lib = nixpkgs.lib;
		forAll = list: f: lib.genAttrs list f;
		callPackage = system: lib.callPackageWith nixpkgs.legacyPackages.${system};

		machines = lib.pipe ./machines [
			builtins.readDir
			(lib.filterAttrs (file: type: type == "directory"))
			builtins.attrNames
		];

	in {
		packages = forAll (builtins.attrNames systemPackages) (system:
			forAll systemPackages.${system} (package:
				callPackage system ./packages/${package}.nix {}
			)
		);
		overlays.default = final: prev: (
			forAll (lib.flatten lib.attrValues systemPackages) (package:
				final.callPackage ./packages/${package}.nix {}
			)
		);
		legacyPackages = forAll (builtins.attrNames systemPackages) (system: {
			cross = import ./cross.nix { inherit system nixpkgs; };
		});
		apps = forAll [ "x86_64-darwin" ] (system: {
			builder-linux = { type = "app"; program = "${self.packages.${system}.builder-linux}/bin/run-nixos-vm"; };
			run-linux = { type = "app"; program = "${self.packages.${system}.run-linux}"; };
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
		checks = forAll (builtins.attrNames systemPackages) (system:
			(forAll systemPackages.${system} (package:
				self.packages.${system}.${package}
			)) // (lib.pipe (forAll machines lib.id) [
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
