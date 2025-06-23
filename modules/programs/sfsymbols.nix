{ config, lib, pkgs, ... }: {

	options.programs.sfSymbols.enable = lib.mkEnableOption "SF Symbols app";

	config = let

		sf-symbols-installer = let
			version = "6.0";
			macOS = "15";
			catalog = "https://swscan.apple.com/content/catalogs/others/index-26-15-14-13-12-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog";
			productId = "042-53422";
		in pkgs.stdenvNoCC.mkDerivation {
			inherit version;
			pname = "sf-symbols-installer";

			src = pkgs.fetchurl {
				url = "https://devimages-cdn.apple.com/design/resources/download/SF-Symbols-6.dmg";
				hash = "sha256-hG6QyidNVtI0pXO698oGVsG4awy8XWr27nEyYSUMhPo=";
			};

			nativeBuildInputs = [ pkgs.undmg ];
			sourceRoot = ".";
			installPhase = "mv 'SF Symbols.pkg' $out";

			passthru.updateScript = lib.optionalString pkgs.stdenv.isDarwin ''
				if test "$(sw_vers -productVersion | cut -d. -f1)" -gt ${macOS} ; then
					printWarning 'Update the software catalog URL for current macOS'
				fi
			'' + ''
				metadata=$(curl --silent '${catalog}' | xmllint --xpath '/plist/dict/dict/key[text()="${productId}"]/following-sibling::dict[1]/key[text()="ServerMetadataURL"]/following-sibling::string[1]/text()' -)
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
			assertion = ! config.programs.sfSymbols.enable || pkgs.stdenv.isDarwin;
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
