{ config, lib, pkgs, ... }: {

	options.services.sshProxy = {
		enableClient = lib.mkEnableOption "ssh proxy client";
		enableServer = lib.mkEnableOption "ssh proxy server";
	};

	config = let

		flakeRepo = "mroi/aws-ssh-proxy";
		flakeRev = "3ec6a4cfea765e7cad53cae2e810fa5caba2802a";
		flakeUrl = "github:${flakeRepo}/${flakeRev}";
		flake = builtins.getFlake flakeUrl;
		flakeAttr = "ssh-proxy";

		ssh-proxy = flake.packages."${config.nixpkgs.system}"."${flakeAttr}" // {
			version = null;
			passthru.updateScript = ''
				rev=$(curl --silent https://api.github.com/repos/${flakeRepo}/git/refs/heads/main | jq --raw-output .object.sha)
				updateRev flakeRev "$rev"
			'';
		};

		clientOrServer = config.services.sshProxy.enableClient || config.services.sshProxy.enableServer;

	in {

		assertions = [{
			assertion = config.services.sshProxy.enableServer -> pkgs.stdenv.isDarwin;
			message = "The SSH proxy server is currently only supported on Darwin";
		}];

		system.build.packages = { inherit ssh-proxy; };

		environment.profile = lib.mkIf (clientOrServer && pkgs.stdenv.isLinux) [
			"github:${flakeRepo}#${flakeAttr}"
		];
		environment.bundles = lib.mkIf (clientOrServer && pkgs.stdenv.isDarwin) {
			"${config.users.shared.folder}/${config.users.serviceDir}/SSHProxy.bundle" = {
				pkg = ssh-proxy;
				install = ''
					makeDir 755::admin "$(dirname "$out")"
					makeTree 755::admin "$out" "$pkg/SSHProxy.bundle"
				'' + lib.optionalString config.services.sshProxy.enableClient ''
					makeDir 700 "$HOME/.ssh"
					makeLink 700 "$HOME/.ssh/ssh-connect" "$out/Contents/MacOS/ssh-connect"
				'' + lib.optionalString config.services.sshProxy.enableServer ''
					plist=/Library/LaunchDaemons/de.reactorcontrol.ssh-proxy.plist
					trace sudo cp "$out/Contents/Resources/de.reactorcontrol.ssh-proxy.plist" "$plist"
					trace sudo /usr/libexec/PlistBuddy -c "Set UserName $(id -un)" "$plist"
					trace sudo /usr/libexec/PlistBuddy -c "Set ProgramArguments:2 '${config.networking.hostName}'" "$plist"
					trace sudo launchctl bootstrap system "$plist"
				'';
			};
		};
	};
}
