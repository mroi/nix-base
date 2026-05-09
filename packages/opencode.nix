# set environment variables to consolidate state in ~/.local/state/opencode
{ opencode, runCommand }:

runCommand "opencode" { inherit (opencode) name; } ''
	mkdir -p $out/bin
	cat <<- 'EOF' > $out/bin/opencode
		#!/bin/sh
		export XDG_DATA_HOME="$HOME/.local/state/opencode"
		export XDG_CACHE_HOME="$XDG_DATA_HOME/cache"
		export NPM_CONFIG_CACHE="$XDG_DATA_HOME/npm"
		${opencode}/bin/opencode "$@"
		clear
	EOF
	chmod a+x $out/bin/opencode
''
