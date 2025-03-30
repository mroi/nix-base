{ config, lib, pkgs, ... }: {

	options.programs.gitup.enable = lib.mkEnableOption "GitUp git frontend";

	config = let

		gitup = pkgs.fetchzip rec {
			pname = "gitup";
			version = "1.4.3";
			url = "https://github.com/git-up/GitUp/releases/download/v${version}/GitUp.zip";
			stripRoot = false;
			hash  = "sha256-JUNC7sOQWs7td06cIlacVfRA1Xj5w+FmnQmUG61ZwIs=";
			passthru.updateScript = ''
				release=$(curl --silent https://api.github.com/repos/git-up/GitUp/releases/latest | jq --raw-output .name)
				version=''${release#v}
				updateVersion version "$version"
				if didUpdate ; then
					curl --silent --location --output GitUp.zip "https://github.com/git-up/GitUp/releases/download/v''${version}/GitUp.zip"
					unzip -q -d GitUp GitUp.zip
					hash=$(nix hash path GitUp)
					updateHash hash "$hash"
					rm -r GitUp GitUp.zip
				fi
			'';
		};

	in {

		assertions = [{
			assertion = ! config.programs.gitup.enable || pkgs.stdenv.isDarwin;
			message = "GitUp is only available on Darwin";
		}];

		system.build.packages = { inherit gitup; };

		environment.bundles = lib.mkIf config.programs.gitup.enable {
			"/Applications/GitUp.app" = {
				pkg = gitup;
				install = ''
					makeTree 755::admin $out "$pkg/GitUp.app"
				'';
			};
		};
	};
}
