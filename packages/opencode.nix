# set environment variables to consolidate state in ~/.local/state/opencode
{ opencode, runCommand, callPackage, mcp-servers ? callPackage (import ./mcp-servers.nix) {} }: let

	# pin to OpenCode 1.19, OpenCode 2 does not support model selection on the command line yet
	# https://github.com/anomalyco/opencode/issues/56218
	nixpkgs = builtins.getFlake "github:NixOS/nixpkgs/48571feca7fb156248ed747dab5860467c141768";
	opencode = nixpkgs.legacyPackages."${mcp-servers.system}".opencode;

in runCommand "opencode" { inherit (opencode) name; } ''
	mkdir -p $out/bin
	cat <<- EOF > $out/bin/opencode
		#!/bin/sh

		# consolidate all state files in XDG_STATE_HOME
		export PATH="\$PATH:$out/libexec"
		export XDG_DATA_HOME="\''${XDG_STATE_HOME:-\$HOME/.local/state}/opencode"
		export XDG_CACHE_HOME="\$XDG_DATA_HOME/cache"
		export NPM_CONFIG_CACHE="\$XDG_DATA_HOME/npm"

		exec ${opencode}/bin/opencode "\$@"
	EOF
	chmod a+x $out/bin/opencode

	mkdir -p $out/libexec
	ln -s ${mcp-servers}/bin/mcp-servers $out/libexec/
''
