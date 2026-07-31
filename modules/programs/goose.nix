{ config, lib, pkgs, ... }: {

	options.programs.goose.enable = lib.mkEnableOption "Goose AI";

	config = lib.mkIf config.programs.goose.enable {

		assertions = [{
			assertion = config.programs.goose.enable -> pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64;
			message = "Goose AI is only available on Darwin";
		}];

		# Goose itself can run unsandboxed due to its reasonable tool call permissions scheme.
		# MCP services launced by Goose however should be invidivually sanboxed to mitigate
		# supply chain attacks or rogue tool accesses by the LLM.
		security.sandbox.enable = lib.mkDefault true;
		security.sandbox.rules = { ... }: "\${GOOSE_SANDBOX_EXTRA_RULES}";

		environment.bundles = {
			"/Applications/Goose.app" = {
				pkg = pkgs.callPackage ../../packages/goose.nix {};
				install = ''
					makeTree 755::admin "$out" "$pkg$out"
					checkSig "$out" 5N2JF58U87

					# wrap goose command line executable
					trace mv $out/Contents/Resources/bin/goose $out/Contents/Resources/bin/.goose-wrapped
					# purge all other internal executables (we run MCP servers with Nix infrastructure)
					trace rm $out/Contents/Resources/bin/*
					trace cat <<- 'EOF' > $out/Contents/Resources/bin/goose
						#!/bin/sh
						# initialize environment as if running in a shell
						eval "$("''${SHELL:-/bin/zsh}" -c 'echo export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}" ; echo export XDG_STATE_HOME="''${XDG_STATE_HOME:-$HOME/.local/state}"')"
						# redirect XDG_DATA_HOME to consolidate all state files in XDG_STATE_HOME
						export XDG_DATA_HOME="$XDG_STATE_HOME"
						# include Nix tools in path
						export PATH="$PATH:$XDG_STATE_HOME/nix/profile/bin:$XDG_STATE_HOME/nix/profile/libexec"
						# launch original goose executable
						exec "$(dirname "$(readlink -f "$0")")/.goose-wrapped" "$@"
					EOF
					trace chmod a+x $out/Contents/Resources/bin/goose

					# re-sign
					trace codesign --sign "$(id -F)" --preserve-metadata=entitlements --force  "$out"
				'';
			};
		};
	};
}
