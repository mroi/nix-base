# a curated set of model-context-protocol (MCP) servers
{ lib, stdenv, writeShellScriptBin, nodejs-slim, uv, }: let

	# cut-off time for auto-loaded package dependencies to get them somewhat pinned
	depsTimestamp = "1779536132";
	depsDate= lib.getAttr stdenv.hostPlatform.uname.system {
		Linux = "$(date --date=@${depsTimestamp} +%Y-%m-%d)";
		Darwin = "$(date -r ${depsTimestamp} +%Y-%m-%d)";
	};

	# run packages from NPM or PyPI using the dependency cutoff to pin dependencies as best as possible
	npx = "${nodejs-slim.npm}/bin/npx --yes --min-release-age $(( ($(date +%s) - ${depsTimestamp} + 43200) / 86400 ))";
	uvx = "${uv}/bin/uvx --exclude-newer=${depsDate}";

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

	# use temporary cache/data directory to isolate MCP server state from
	# the user’s regular command line tools state
	tmpdir=$TMPDIR/mcp-server-$USER
	export XDG_DATA_HOME=$tmpdir
	export XDG_CACHE_HOME=$tmpdir
	export NPM_CONFIG_CACHE=$tmpdir
	cd $tmpdir

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

	passthru.updateScript = ''
		updateNPM() {
			version=$(curl --silent "https://registry.npmjs.org/$2/latest" | jq --raw-output .version)
			updateVersion "$1" "$version"
		}
		updatePyPI() {
			version=$(curl --silent "https://pypi.org/pypi/$2/json" | jq --raw-output .info.version)
			updateVersion "$1" "$version"
		}

		# dependency cutoff time
		timestamp=$(jq .nodes.nixpkgs.locked.lastModified "$_self/flake.lock")
		updateVersion depsTimestamp "$timestamp"
	'';
}
