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

			target="${lib.concatLines normalizedProfile}"
			if ! nix registry list | grep -Fq ' flake:nix-base ' ; then
				# use the origin of the rebuild script when nix-base is not a registered flake
				# shellcheck disable=SC2154
				target=$(echo "$target" | sed "s|^flake:nix-base#|path:''${self}#|")
			fi

			current="$(nix profile list --json | ${jq} --raw-output '.elements | keys[] as $name | "\($name)=\(.[$name].originalUrl)#\(.[$name].attrPath | sub("[^.]*\\.[^.]*\\."; ""))"')"

			# remove packages not in target profile
			forCurrent() {
				package=''${1#*=}
				if ! hasLine "$target" "$package" ; then
					toRemove="$toRemove ''${1%=*}"
				fi
			}
			forLines "$current" forCurrent

			# install packages not in current profile
			forTarget() {
				package=$1
				found=false
				forCurrent() { if test "$package" = "''${1#*=}" ; then found=true ; fi ; }
				forLines "$current" forCurrent
				if ! $found ; then
					toInstall="$toInstall $1"
				fi
			}
			forLines "$target" forTarget

			# execute all changes
			if test "$toRemove" ; then
				# shellcheck disable=SC2086
				trace nix profile remove --quiet $toRemove
			fi
			if test "$toInstall" ; then
				# shellcheck disable=SC2086
				trace nix profile install --quiet $toInstall
			fi
		'';

		system.updateScripts.profile = lib.stringAfter [ "packages" ] ''
			storeHeading -
			trace nix profile upgrade --all
		'';
		system.cleanupScripts.profile = lib.stringAfter [ "packages" ] ''
			storeHeading 'Cleaning the Nix profile'
			trace nix profile wipe-history
		'';
	};
}
