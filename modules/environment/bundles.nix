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
		description = "Installation of side-loaded apps and other bundles, keyed by bundle path which may contain environment variables.";
	};

	config = let

		bundleScript = path: attrs: ''
			# extract version string
			out=$(eval echo '${path}')
			if test -r "$out/Contents/Info.plist" ; then
				version=$(xmllint --xpath '/plist/dict/key[text()="CFBundleShortVersionString"]/following-sibling::string[1]/text()' "$out/Contents/Info.plist")
			else
				version=
			fi
			# conditional installation
			if test "$version" != '${attrs.pkg.version}' ; then
				pkg=${pkgs.lazyBuild attrs.pkg}
				${attrs.install}
			fi
		'';

	in lib.mkIf (config.environment.bundles != {}) {

		assertions = [{
			assertion = config.environment.bundles == {} || pkgs.stdenv.isDarwin;
			message = "Bundle installation is only available on Darwin";
		} {
			assertion = lib.all (lib.hasAttr "version") (lib.catAttrs "pkg" (lib.attrValues config.environment.bundles));
			message = "Packages to install as bundles must have a version attribute";
		}];

		system.activationScripts.bundles = ''
			storeHeading 'Installing side-loaded bundles'
			${lib.pipe config.environment.bundles [
				(lib.mapAttrs bundleScript)
				lib.attrValues
				lib.concatLines
			]}
		'';

		system.updateScripts.bundles = config.system.activationScripts.bundles;
	};
}
