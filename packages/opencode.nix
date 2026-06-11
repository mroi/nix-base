# set environment variables to consolidate state in ~/.local/state/opencode
{ stdenv, opencode, runCommand, callPackage, mcp-servers ? callPackage (import ./mcp-servers.nix) {} }:

let
	# bun creates an opencode binary with a broken signature, macOS ≥ 27 rejects this
	opencode' = if stdenv.isDarwin then opencode.overrideAttrs (attrs: {
		__noChroot = true;
		# do not run smoke test, because the binary is still broken here
		postPatch = attrs.postPatch + ''
			substituteInPlace packages/opencode/script/build.ts --replace-fail \
				'if (item.os === process.platform && item.arch === process.arch && !item.abi) {' \
				'if (false) {'
		'';
		# fix the signature by resigning
		postBuild = "/usr/bin/codesign -f -s - dist/opencode-darwin-arm64/bin/opencode";
	}) else opencode;

in runCommand "opencode" { inherit (opencode) name; } ''
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
			${opencode'}/bin/opencode "\$@"
			clear
		else
			exec ${opencode'}/bin/opencode "\$@"
		fi
	EOF
	chmod a+x $out/bin/opencode

	mkdir -p $out/libexec
	ln -s ${mcp-servers}/bin/mcp-servers $out/libexec/
''
