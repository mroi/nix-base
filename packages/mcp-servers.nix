# a curated set of model-context-protocol (MCP) servers
{ lib, stdenv, writeShellScriptBin, nodejs-slim, uv, mcp-nixos, fetchFromGitHub, swift, swiftpm, git, cacert }: let

	versions = {
		apple-docs = "1.0.1";
		pdf-reader = "8.5.5";
		web-search = "0.7.0";
	};

	# cut-off time for auto-loaded package dependencies to get them somewhat pinned
	depsTimestamp = "1792506237";
	depsDate= lib.getAttr stdenv.hostPlatform.uname.system {
		Linux = "$(date --date=@${depsTimestamp} +%Y-%m-%d)";
		Darwin = "$(date -r ${depsTimestamp} +%Y-%m-%d)";
	};

	# run packages from NPM or PyPI using the dependency cutoff to pin dependencies as best as possible
	npx = "${nodejs-slim.npm}/bin/npx --yes --min-release-age $(( ($(date +%s) - ${depsTimestamp} + 43200) / 86400 ))";
	uvx = "${uv}/bin/uvx --exclude-newer=${depsDate}";

	servers = {

		nixos = "exec ${mcp-nixos}/bin/mcp-nixos \"$@\"";
		pdf-reader = "exec ${npx} @sylphx/anymd@${versions.pdf-reader} \"$@\"";
		web-search = "exec ${uvx} duckduckgo-mcp-server==${versions.web-search} \"$@\"";

	} // lib.optionalAttrs stdenv.hostPlatform.isDarwin {

		apple-docs = "exec ${apple-docs}/bin/Apple-Docs-MCP \"$@\"";

	};

	apple-docs = stdenv.mkDerivation {
		pname = "apple-docs-mcp";
		version = versions.apple-docs;
		src = fetchFromGitHub {
			owner = "justindal";
			repo = "Apple-Docs-MCP";
			rev = "v${versions.apple-docs}";
			hash = "sha256-Yvx+ybPHeLTKo/orCwatVi4Zq7nyoA3BxaAVysh9Ef0=";
		};
		patches = ./mcp-apple-docs.patch;
		__noChroot = true;
		nativeBuildInputs = [ git cacert swift swiftpm ];
		installPhase = "mkdir -p $out/bin ; cp .build/release/Apple-Docs-MCP $out/bin/";
	};

in (writeShellScriptBin "mcp-servers" ''

	if test "$#" -eq 0 ; then
		echo "Usage: $0 <server> [...]"
		echo
		echo 'Available MCP servers:'
		${lib.pipe servers [
			lib.attrNames
			(map (name: "echo '${name}'"))
			lib.concatLines
		]}
		exit 0
	fi

	# MCP server downloads go into a custom cache directory
	if test -d "''${XDG_STATE_HOME:-"$HOME/.local/state"}/opencode" ; then
		cache=''${XDG_STATE_HOME:-"$HOME/.local/state"}/opencode/cache/mcp-servers/${depsTimestamp}
	else
		cache=''${XDG_CACHE_HOME:-"$HOME/.cache"}/mcp-servers/${depsTimestamp}
	fi
	mkdir -p "$cache" 2> /dev/null
	for dir in "''${cache%/*}/"* ; do test "$dir" = "$cache" || rm -rf "$dir" ; done
	export XDG_DATA_HOME=$cache
	export XDG_CACHE_HOME=$cache
	export NPM_CONFIG_CACHE=$cache
	cd "$cache"

	export NIX_SSL_CERT_FILE=${lib.getAttr stdenv.hostPlatform.uname.system {
		Linux = "/etc/ssl/certs/ca-certificates.crt";
		Darwin = "/etc/ssl/cert.pem";
	}}
	export PATH=${nodejs-slim}/bin:/usr/bin:/bin:/usr/sbin:/sbin

	server=$1
	shift

	# run server-specific commands
	case "$server" in
		${lib.pipe servers [
			(lib.mapAttrsToList (name: value: "(${name}) ${value} ;;"))
			lib.concatLines
		]}
	esac

'') // {

	# include the list of MCP servers in the derivation to externally generate configuration files
	servers = lib.attrNames servers;

	passthru.updateScript = ''
		# dependency cutoff time
		timestamp=$(jq .nodes.nixpkgs.locked.lastModified "$_self/flake.lock")
		updateVersion depsTimestamp "$timestamp"

		# only update the NPM and PyPI packages if we updated the dependency cutoff
		# otherwise unsatisfiable version combinations will be requested
		if didUpdate ; then
			updateNPM() {
				version=$(curl --silent "https://registry.npmjs.org/$2/latest" | jq --raw-output .version)
				updateVersion "$1" "$version"
			}
			updatePyPI() {
				version=$(curl --silent "https://pypi.org/pypi/$2/json" | jq --raw-output .info.version)
				updateVersion "$1" "$version"
			}

			updatePyPI web-search duckduckgo-mcp-server
			updateNPM pdf-reader @sylphx/anymd
		fi

		# apple-docs
		release=$(curl --silent https://api.github.com/repos/justindal/Apple-Docs-MCP/releases/latest | jq --raw-output .name)
		version=''${release#v}
		updateVersion apple-docs "$version"
	'';
}
