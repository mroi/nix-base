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
						if \$_hasColorStdout ; then
							printInfo \"\$(tput smul)Processing \${n}\$(tput rmul)\"
						else
							printInfo 'Processing \${n}'
						fi
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
		cd "${self}" || exit
		# add relevant tools to the path
		eval "$(nix eval --quiet --no-warn-dirty --raw \
			--apply 'pkgs: builtins.foldl'\'' (acc: elem: '\'\''${acc}
				nix build --quiet --no-link ${pkgs."${elem}".drvPath}^out
				PATH=$PATH:${pkgs."${elem}"}/bin
			'\'\'') "" (builtins.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = [ "nix-update" ];
				Darwin = [ "nix-update" ];
			})' \
			"${self}#baseConfigurations.${machine}.config.nixpkgs.pkgs"
		)"
		eval "$_updatesExternal" "$_updatesInternal"
	)
}

# helper functions for per-package update scripts

nixUpdate() {
	NIX_SSL_CERT_FILE=$_sslCertFile nix-update --flake "$@" | sed -n '
		/^fetch /Ip
		/^update /Ip
		/^no changes /Ip
	'
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
		_current=$(sed -n -E "/$_trigger/,\${
			s!.*\"($_match)\".*!\1!
			t print
			b
			:print
			p;q
		}" "$_file")
		if test "$_current" != "$_value" ; then
			printInfo "${UPDATE_NIX_ATTR_PATH##*.} $_type $_current -> $_value"
			# replace first _match after the first line mentioning _trigger
			sed -E -i_ "/$_trigger/,\${
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
	fi
}

didUpdate() {
	if test "$_update" = true ; then return 0 ; else return 1 ; fi
}

updateVersion() {
	_updateEntry version "$1" '[0-9][[:alnum:].+-]*' "$2"
}
updateHash() {
	_updateEntry hash "$1" '(md5|sha1|sha256|sha512)-[[:alnum:]/+=]+' "$2"
}
updateRev() {
	_updateEntry revision "$1" '[0-9a-f]{40}' "$2"
}
