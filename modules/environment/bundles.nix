{ config, lib, pkgs, ... }: {

	options.environment.bundles = lib.mkOption {
		type = lib.types.attrsOf (lib.types.submodule { options = {
			pkg = lib.mkOption {
				type = lib.types.package;
				description = "The package from which the bundle is installed, will be built lazily.";
			};
			install = lib.mkOption {
				type = lib.types.lines;
				description = "Script commands to install the bundle from the package.";
			};
		};});
		default = {};
		description = "Installation of side-loaded apps and other bundles, keyed by bundle path.";
	};

	config = let

		bundleScript = mode: path: attrs: lib.optionalString (mode == "update") ''
			# extract version string
			if test -r '${path}/Contents/Info.plist' ; then
				version=$(xmllint --xpath '/plist/dict/key[text()="CFBundleShortVersionString"]/following-sibling::string[1]/text()' '${path}/Contents/Info.plist' 2> /dev/null || true)
			else
				version=
			fi
			# update when versions are different
			if test "$version" != '${toString attrs.pkg.version}' ; then
		'' + lib.optionalString (mode == "install") ''
			if ! test -d '${path}' ; then
		'' + ''
				pkg=${pkgs.lazyBuild attrs.pkg}
				out=${path}
				${attrs.install}
			fi
		'';

		allBundlesScript = mode: lib.pipe config.environment.bundles [
			(lib.mapAttrs (bundleScript mode))
			lib.attrValues
			lib.concatLines
		];

	in lib.mkIf (config.environment.bundles != {}) {

		assertions = [{
			assertion = config.environment.bundles == {} || pkgs.stdenv.isDarwin;
			message = "Bundle installation is only available on Darwin";
		} {
			assertion = lib.all (lib.hasPrefix "/") (lib.attrNames config.environment.bundles);
			message = "Bundle attribute names must be absolute paths";
		} {
			assertion = lib.all (lib.hasAttr "version") (lib.catAttrs "pkg" (lib.attrValues config.environment.bundles));
			message = "Packages to install as bundles must have a version attribute";
		}];

		system.activationScripts.bundles = ''
			storeHeading 'Installing side-loaded software'
			${allBundlesScript "install"}
		'';

		system.updateScripts.bundles = ''
			storeHeading 'Updating side-loaded software'
			${allBundlesScript "update"}
		'';
	};
}
