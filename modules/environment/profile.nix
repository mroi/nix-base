{ config, lib, pkgs, ... }: {

	options.environment.profile = lib.mkOption {
		type = lib.types.nullOr (lib.types.listOf (lib.types.strMatching ".*#.*"));
		default = [];
		example = [ "nixpkgs#hello" ];
		description = "The Nix packages to be installed in the Nix profile, given as flake references with short (no `packages` or `legacyPackages` prefix) package names.";
	};

	config = let

		normalizedProfile = lib.pipe config.environment.profile [
			(map (lib.splitString "#"))
			(map (x: { first = lib.elemAt x 0; second = lib.elemAt x 1; }))
			(map (x: {
				flake = builtins.flakeRefToString (builtins.parseFlakeRef x.first);
				attrs = x.second;
			}))
			(map (x: "${x.flake}#${x.attrs}"))
		];

		jq = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
			Linux = lib.getExe pkgs.jq;
			Darwin = lib.getExe pkgs.jq;  # TODO: plain "jq" when we drop support for macOS <15
		};

	in lib.mkIf (config.environment.profile != null) {
		system.activationScripts.profile = lib.stringAfter [ "nix" ] ''
			storeHeading 'Updating the Nix profile'

			targetProfile="${lib.concatLines normalizedProfile}"
			if ! nix registry list | grep -Fq ' flake:nix-base ' ; then
				# use the origin of the rebuild script when nix-base is not a registered flake
				# shellcheck disable=SC2154
				targetProfile=$(echo "$targetProfile" | sed "s|^flake:nix-base#|path:''${self}#|")
			fi

			currentProfile="$(nix profile list --json | ${jq} --raw-output '.elements | keys[] as $name | "\($name)=\(.[$name].originalUrl)#\(.[$name].attrPath | sub("[^.]*\\.[^.]*\\."; ""))"')"

			# remove packages not in target profile
			forCurrent() {
				currentPackage=''${1#*=}
				found=false
				forTarget() { if test "$currentPackage" = "$1" ; then found=true ; fi }
				forLines "$targetProfile" forTarget
				if ! $found ; then
					toRemove="$toRemove ''${1%=*}"
				fi
			}
			forLines "$currentProfile" forCurrent

			# install packages not in current profile
			forTarget() {
				targetPackage=$1
				found=false
				forCurrent() { if test "$targetPackage" = "''${1#*=}" ; then found=true ; fi }
				forLines "$currentProfile" forCurrent
				if ! $found ; then
					toInstall="$toInstall $1"
				fi
			}
			forLines "$targetProfile" forTarget

			# execute all changes
			if test "$toRemove" ; then
				# shellcheck disable=SC2086
				trace nix profile remove --quiet $toRemove
			fi
			if test "$toInstall" ; then
				# shellcheck disable=SC2086
				trace nix profile install --quiet $toInstall
			fi
			if checkArgs --update-profile --update -u ; then
				trace nix profile upgrade --all
			fi
		'';
	};
}
