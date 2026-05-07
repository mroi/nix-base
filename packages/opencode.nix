# set environment variables to consolidate state in ~/.local/state/opencode
{ opencode, runCommand }:

runCommand "opencode" { inherit (opencode) name; } ''
	mkdir -p $out/bin
	cat <<- EOF > $out/bin/opencode
		#!/bin/sh

		# consolidate all state files in XDG_DATA_HOME
		export PATH="\$PATH:$out/libexec"
		export XDG_DATA_HOME="\''${XDG_STATE_HOME:-\$HOME/.local/state}/opencode"
		export XDG_CACHE_HOME="\$XDG_DATA_HOME/cache"
		export NPM_CONFIG_CACHE="\$XDG_DATA_HOME/npm"

		# detect TUI invocations: no subcommand given
		case "\$1" in
			--help|-h|--version|-v) tui=false ;;
			-*) tui=true ;;
			"") tui=true ;;
			*) test -e "\$1" && tui=true || tui=false
		esac

		# run opencode
		if \$tui ; then
			${opencode}/bin/opencode "\$@"
			clear
		else
			exec ${opencode}/bin/opencode "\$@"
		fi
	EOF
	chmod a+x $out/bin/opencode
''
