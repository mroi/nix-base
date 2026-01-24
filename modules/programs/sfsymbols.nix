{ config, lib, pkgs, ... }: {

	options.programs.sfSymbols.enable = lib.mkEnableOption "SF Symbols app";

	config = let

		sf-symbols-installer = let
			version = "7.0";
			major = lib.head (lib.match "([0-9]+)\..*" version);
			# product ID: 042-53422
			catalog = "https://swscan.apple.com/content/catalogs/others/index-26-15-14-13-12-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog";
			macOS = lib.elemAt (lib.splitString "-" catalog) 1;
		in pkgs.stdenvNoCC.mkDerivation {
			inherit version;
			pname = "sf-symbols-installer";

			src = pkgs.fetchurl {
				url = "https://devimages-cdn.apple.com/design/resources/download/SF-Symbols-${major}.dmg";
				hash = "sha256-RNH7JXEXt/ne5K8a10N2JZW/Y9+Z84JMVJeq3XL4tWw=";
			};

			nativeBuildInputs = [ pkgs.undmg ];
			sourceRoot = ".";
			installPhase = "mv 'SF Symbols.pkg' $out";

			passthru.updateScript = lib.optionalString pkgs.stdenv.isDarwin ''
				if test "$(sw_vers -productVersion | cut -d. -f1)" -gt ${macOS} ; then
					printWarning 'Update the software catalog URL for current macOS'
				fi
			'' + ''
				metadata=$(curl --silent '${catalog}' | xmllint --xpath '/plist/dict/dict/dict/key[text()="ServerMetadataURL"]/following-sibling::string[contains(text(),"SFSymbols")]/text()' -)
				version=$(curl --silent "$metadata" | xmllint --xpath '/plist/dict/key[text()="CFBundleShortVersionString"]/following-sibling::string[1]/text()' -)
				updateVersion version "$version"
				if didUpdate ; then
					major=$(echo "$version" | cut -d. -f1)
					url="https://devimages-cdn.apple.com/design/resources/download/SF-Symbols-$major.dmg"
					hash=$(curl --silent "$url" | nix hash file /dev/stdin)
					updateHash hash "$hash"
				fi
			'';
		};

	in  {

		assertions = [{
			assertion = config.programs.sfSymbols.enable -> pkgs.stdenv.isDarwin;
			message = "SF Symbols is only available on Darwin";
		}];

		system.build.packages = { inherit sf-symbols-installer; };

		environment.bundles = lib.mkIf config.programs.sfSymbols.enable {
			"/Applications/SF Symbols.app" = {
				pkg = sf-symbols-installer;
				install = ''
					installPackage "$pkg"
					checkSig "$out"
				'';
			};
		};
	};
}
