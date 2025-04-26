{ config, lib, pkgs, ... }: {

	options.services.unison.awsSync = lib.mkEnableOption "Unison AWS sync";

	config = let

		flakeRepo = "mroi/aws-ssh-proxy";
		flakeRev = "5eab5030cf51c71acc873d8508667326cbae78e6";
		flakeUrl = "github:${flakeRepo}/${flakeRev}";
		flake = builtins.getFlake flakeUrl;
		flakeAttr = "unison-sync";
		flakeBranch = flakeAttr;

		unison-sync = flake.packages."${config.nixpkgs.system}"."${flakeAttr}" // {
			version = null;
			passthru.updateScript = ''
				rev=$(curl --silent https://api.github.com/repos/${flakeRepo}/git/refs/heads/${flakeBranch} | jq --raw-output .object.sha)
				updateRev flakeRev "$rev"
			'';
		};

	in {

		system.build.packages = { inherit unison-sync; };

		environment.profile = lib.mkIf (config.services.unison.awsSync && pkgs.stdenv.isLinux) [
			"github:${flakeRepo}/${flakeBranch}#${flakeAttr}"
		];
		environment.bundles = lib.mkIf (config.services.unison.awsSync && pkgs.stdenv.isDarwin) {
			"${config.users.shared.folder}/${config.users.serviceDir}/UnisonSync.bundle" = {
				pkg = unison-sync;
				install = ''
					makeDir 755::admin "$(dirname "$out")"
					makeTree 755::admin "$out" "$pkg/UnisonSync.bundle"
					makeDir 700 "$HOME/.ssh"
					makeLink 700 "$HOME/.ssh/unison-connect" "$out/Contents/MacOS/unison-connect"
				'';
			};
		};
	};
}
