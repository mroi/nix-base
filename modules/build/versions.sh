# update packages to current versions

# shellcheck disable=SC2016,SC2154
test "$self" || fatalError '$self is unset'
test "$machine" || fatalError '$machine is unset'

runAllUpdates() {
	_system=$(nix eval --impure --raw --expr builtins.currentSystem)

	_nixFunc() {
		# shellcheck disable=SC2028
		echo "x: builtins.concatStringsSep \"\\n\" (
			builtins.attrValues (
				builtins.mapAttrs (n: v:
					if builtins.isString v.passthru.updateScript or null then ''
						printSubheading \"Processing \${n}\"
						export UPDATE_NIX_ATTR_PATH=\"$1.\${n}\"
						\${v.passthru.updateScript}
					'' else \"\"
				) x
			)
		)"
	}

	_updatesExternal=$(nix eval --quiet --no-warn-dirty --raw \
		--apply "$(_nixFunc "packages.${_system}")" \
		"${self}#packages.${_system}" || true)
	_updatesInternal=$(nix eval --quiet --no-warn-dirty --raw \
		--apply "$(_nixFunc "baseConfigurations.${machine}.config.system.build.packages")" \
		"${self}#baseConfigurations.${machine}.config.system.build.packages" || true)

	storeHeading 'Updating package versions'
	(
		cdTemporaryDirectory
		export PATH=/usr/bin:/bin:/usr/sbin:/sbin
		PATH=$PATH:${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile/bin

		# add relevant tools to the path
		eval "$(nix eval --quiet --no-warn-dirty --raw \
			--apply 'pkgs: builtins.foldl'\'' (acc: elem: let
				output = if pkgs."${elem}" ? bin then "bin" else "out";
			in '\'\''${acc}
				nix build --quiet --no-link ${pkgs."${elem}".drvPath}^${output}
				PATH=${pkgs."${elem}"."${output}"}/bin:$PATH
			'\'\'') "" (builtins.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = [ "nix-update" "curl" "jq" "libxml2" ];
				Darwin = [ "nix-update" "jq" ];  # TODO: remove jq when we drop support for macOS <15
			})' \
			"${self}#baseConfigurations.${machine}.config.nixpkgs.pkgs"
		)"

		# execute all passthru.updateScript entries
		eval "$_updatesExternal" "$_updatesInternal"
	)
}

# helper functions for per-package update scripts

nixUpdate() {
	_pwd=$PWD
	cd "$self" || exit
	NIX_CONF_DIR=/nix NIX_SSL_CERT_FILE=$_sslCertFile nix-update --flake "$@" | sed -n '
		/^fetch /Ip
		/^update /Ip
		/^no changes /Ip
	'
	cd "$_pwd" || exit
}

_updateEntry() {
	_type=$1
	_trigger=$2
	_match=$3
	_value=$4
	_update=false

	if test "$_value" ; then
		# get file information
		_file=$(nix eval --quiet --no-warn-dirty --raw \
			--apply 'x: with builtins;
				substring (stringLength storeDir) (-1) (unsafeGetAttrPos "updateScript" x.passthru).file' \
			"${self}#$UPDATE_NIX_ATTR_PATH")
		_file=${self}/${_file#/*/}
		# extract current value: first _match after the first line mentioning _trigger
		_current=$(sed -n -E "/$_trigger/,\$ {
			s!.*\"($_match)\".*!\1!
			t print
			b
			:print
			p ; q
		}" "$_file")
		if test "$_current" != "$_value" ; then
			printInfo "${UPDATE_NIX_ATTR_PATH##*.} $_type $_current -> $_value"
			# replace first _match after the first line mentioning _trigger
			sed -E -i_ "/$_trigger/,\$ {
				s!\"$_match\"!\"$_value\"!
				t loop
				b
				:loop
				n
				b loop
			}" "$_file"
			rm "${_file}_"
			_update=true
		else
			printInfo "${UPDATE_NIX_ATTR_PATH##*.} $_type unchanged"
		fi
	else
		fatalError "unexpected empty $_type value"
	fi
}

didUpdate() {
	if test "$_update" = true ; then return 0 ; else return 1 ; fi
}

updateVersion() {
	_updateEntry version "$1" '[[:alnum:].+-]+' "$2"
}
updateUrl() {
	_updateEntry url "$1" '(http|https)://[^"]+' "$2"
}
updateHash() {
	_updateEntry hash "$1" '(md5|sha1|sha256|sha512)-[[:alnum:]/+=]+' "$2"
}
updateRev() {
	_updateEntry revision "$1" '[0-9a-f]{40}' "$2"
}

if test "$GITHUB_TOKEN" ; then
curl() {
	if test "${*#*github.com}" != "$*" ; then
		command curl --header "Authorization: Bearer $GITHUB_TOKEN" "$@"
	else
		command curl "$@"
	fi
}
fi
