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
		PATH=$PATH$(nix eval --quiet --no-warn-dirty --raw \
			--apply 'pkgs: builtins.foldl'\'' (
				acc: elem: "${acc}:${pkgs."${elem}"}/bin"
			) "" (builtins.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = [ "nix-update" ];
				Darwin = [ "nix-update" ];
			})' \
			"${self}#baseConfigurations.${machine}.config.nixpkgs.pkgs"
		)
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
