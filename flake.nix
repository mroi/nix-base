{
	description = "custom Nix packages";
	outputs = { self, nixpkgs }: let
		systemPackages = {
			aarch64-darwin = [
				"arq-restore" "builder-linux" "fish" "hires" "nix" "run-linux" "texlive"
				"unison" "unison-fsmonitor" "vmware-vmx"
			];
			x86_64-darwin = [
				"arq-restore" "builder-linux" "fish" "hires" "nix" "run-linux" "texlive"
				"unison" "unison-fsmonitor" "vmware-vmx"
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
		baseConfigurations = forAll (builtins.attrNames (builtins.readDir ./machines)) (machine:
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
			)) // (forAll (builtins.attrNames (builtins.readDir ./machines)) (machine:
				nixpkgs.legacyPackages.${system}.stdenvNoCC.mkDerivation {
					name = machine;
					phases = [ "installPhase" ];
					installPhase = ''
						mkdir $out
						ln -s ${self.baseConfigurations.${machine}.config.system.build.toplevel} $out/activate
						ln -s ${self.baseConfigurations.${machine}.config.system.build.manual} $out/manual
					'';
				}
			))
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
