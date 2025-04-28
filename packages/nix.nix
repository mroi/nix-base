# wrapper script for Nix which improves upon nix develop and nix shell
# nix develop: enable flakey use of shell.nix files, which have less boilerplate than flake.nix
# nix shell: set environment variable for shell environment beautification in shell config
{ lib, stdenvNoCC, nix }:

stdenvNoCC.mkDerivation {
	name = nix.name;
	src = null;
	propagatedUserEnvPkgs = [ nix.out nix.man ];
	phases = "installPhase fixupPhase";
	installPhase = let tmpPattern = if stdenvNoCC.isDarwin then "nix" else "nix.XXXXXXXX"; in ''
		mkdir -p $out/bin
		cat <<- 'EOFEOF' > $out/bin/nix
			#!/bin/sh

			# parse arguments to extract mode and derivation
			for arg ; do
				case "$arg" in
				-*)
					break
					;;
				*)
					if test -z "$mode" ; then
						mode=$arg
					else
						pkg=$arg
					fi
					;;
				esac
			done

			# handle daemon invocation
			if test "$mode" = daemon ; then
				exec ${nix}/bin/nix $nix_settings --experimental-features nix-command "$@"
			fi

			# environment variables
			export NIX_CONF_DIR=/nix
	'' + lib.optionalString stdenvNoCC.isDarwin ''
			export NIX_SSL_CERT_FILE=/etc/ssl/cert.pem
			# store cache files in temporary directory, configure shell
			export XDG_CACHE_HOME=''${XDG_CACHE_HOME:-''${TMPDIR%/T/}/C}
			export TMPDIR=/nix/var/tmp
			export SHELL_SESSION_DID_INIT=1
			export HISTFILE=/dev/null
	'' + lib.optionalString stdenvNoCC.isLinux ''
			export NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
			# configure shell
			export HISTFILE=/dev/null
	'' + ''

			# build a temporary flake from shell.nix when 'nix develop' is run
			if test "$mode" = develop -a "$pkg" = "" -a ! -r flake.nix -a -r shell.nix ; then
				tmp=$(realpath $(mktemp -d -t ${tmpPattern}))
				trap 'rm -rf "$tmp"' EXIT HUP INT TERM QUIT

				cp shell.nix "$tmp/"
				test -r shell.lock && cp shell.lock "$tmp/flake.lock"
				cat <<- 'EOF' > "$tmp/flake.nix"
					{
						outputs = { self, nixpkgs }: let
							systems = [ "aarch64-linux" "aarch64-darwin" "x86_64-linux" "x86_64-darwin" ];
							forAll = list: f: nixpkgs.lib.genAttrs list f;
						in {
							devShells = forAll systems (system: {
								default = (import ./shell.nix { 
									inherit nixpkgs system;
								}).overrideAttrs (attrs: {
									shellHook = (attrs.shellHook or "") + '''
										test -r ~/.local/config/shell/rc && . ~/.local/config/shell/rc
									''';
								});
							});
						};
					}
				EOF

				${nix}/bin/nix --experimental-features 'nix-command flakes' "$@" --impure "$tmp"

				result=$?
				test -r "$tmp/flake.lock" -a ! -r shell.lock && cp -p "$tmp/flake.lock" shell.lock
				exit $result
			fi

			# enable shell postprocessing
			if test "$mode" = shell ; then
				export NIX_SHELL_POSTPROC=1
			fi

			exec ${nix}/bin/nix --experimental-features 'nix-command flakes' "$@"
		EOFEOF
		chmod a+x $out/bin/nix
	'';
}
