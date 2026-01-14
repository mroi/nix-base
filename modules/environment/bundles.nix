{ config, lib, pkgs, ... }: {

	options.environment.bundles = lib.mkOption {
		type = lib.types.attrsOf (lib.types.submodule { options = {
			pkg = lib.mkOption {
				type = lib.types.package;
				description = "The package from which the bundle is installed, will be built lazily.";
			};
			install = lib.mkOption {
				type = lib.types.lines;
				example = lib.literalExpression ''
					makeTree 755::admin "$out" "$pkg$out"
					checkSig "$out" 8J894P55M8
				'';
				description = "Script commands to install the bundle from the package.";
			};
		};});
		default = {};
		description = "Installation of side-loaded apps and other bundles, keyed by bundle path.";
	};

	config = let

		bundleScript = mode: path: attrs: lib.optionalString (mode == "update") ''
			# extract version string
			if test -r '${path}/Contents/Info.plist' && plutil -extract CFBundleShortVersionString raw '${path}/Contents/Info.plist' > /dev/null 2>&1 ; then
				version=$(plutil -extract CFBundleShortVersionString raw '${path}/Contents/Info.plist')
			else
				version=
			fi
			# update when versions are different
			if test "$version" != '${toString attrs.pkg.version}' ; then
		'' + lib.optionalString (mode == "install") ''
			if ! test -d '${path}' ; then
		'' + ''
				pkg=${pkgs.lazyBuild attrs.pkg}
				out=${lib.escapeShellArg path}

				${attrs.install}

				case "$out" in
				*.app)
					trace /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$out" ;;
				esac
			fi
		'';

		allBundlesScript = mode: lib.pipe config.environment.bundles [
			(lib.mapAttrs (bundleScript mode))
			lib.attrValues
			lib.concatLines
		];

	in lib.mkIf (config.environment.bundles != {}) {

		assertions = [{
			assertion = config.environment.bundles != {} -> pkgs.stdenv.isDarwin;
			message = "Bundle installation is only available on Darwin";
		} {
			assertion = lib.all (lib.hasPrefix "/") (lib.attrNames config.environment.bundles);
			message = "Bundle attribute names must be absolute paths";
		} {
			assertion = lib.all (lib.hasAttr "version") (lib.catAttrs "pkg" (lib.attrValues config.environment.bundles));
			message = "Packages to install as bundles must have a version attribute";
		}];

		system.activationScripts.bundles = lib.stringAfter [ "nix" "volumes" ] ''
			storeHeading 'Installing side-loaded software'
			${allBundlesScript "install"}
		'';

		system.updateScripts.bundles = lib.stringAfter [ "apps" ] ''
			storeHeading 'Updating side-loaded software'
			${allBundlesScript "update"}
		'';
	};
}
