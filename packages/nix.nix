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

	'' + lib.optionalString stdenvNoCC.isDarwin ''
			# store state and cache files in temporary directory, configure shell
			export XDG_STATE_HOME=$TMPDIR
			export XDG_DATA_HOME=$TMPDIR
			export XDG_CACHE_HOME=$TMPDIR/../C
			export SHELL_SESSION_DID_INIT=1
			export HISTFILE=/dev/null
	'' + lib.optionalString stdenvNoCC.isLinux ''
			# configure shell
			export HISTFILE=/dev/null
	'' + ''

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
						drv=$arg
					fi
					;;
				esac
			done

			# build a temporary flake from shell.nix when 'nix develop' is run
			if test "$mode" = develop -a "$drv" = "" -a ! -r flake.nix -a -r shell.nix ; then
				tmp=$(mktemp -d -t ${tmpPattern})
				trap 'rm -rf "$tmp"' EXIT HUP INT TERM QUIT

				cp shell.nix "$tmp/"
				test -r shell.lock && cp shell.lock "$tmp/flake.lock"
				cat <<- 'EOF' > "$tmp/flake.nix"
					{
						outputs = { self, nixpkgs }: let
							systems = [ "x86_64-linux" "x86_64-darwin" ];
							forAll = list: f: nixpkgs.lib.genAttrs list f;
						in {
							devShells = forAll systems (system: {
								default = import ./shell.nix { inherit nixpkgs system; };
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
