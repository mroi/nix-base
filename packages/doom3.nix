# Doom 3 game engine
{ lib, stdenvNoCC, fetchurl, undmg, writeText, doom3-gamedata ? null }:

stdenvNoCC.mkDerivation rec {
	pname = "doom3";
	version = "1.5.4";

	src = fetchurl {
		url = "https://github.com/MacSourcePorts/MSPBuildSystem/releases/download/dhewm3_1.5.4_2025-07-12/dhewm3-1.5.4.dmg";
		hash = "sha256-3NYe6+G4oRZfgeodrvNddR+PxAXppm73M6tVcNxnyV4=";
	};

	nativeBuildInputs = [ undmg ];
	sourceRoot = ".";
	__noChroot = true;

	patches = writeText "app-store-category.patch" ''
		--- a/dhewm3.app/Contents/Info.plist
		+++ b/dhewm3.app/Contents/Info.plist
		@@ -25,7 +25,7 @@
		     <key>NSHighResolutionCapable</key>
		     <true/>
		     <key>LSApplicationCategoryType</key>
		-    <string>public.app-category.games</string>
		+    <string>public.app-category.action-games</string>
		 </dict>
		 </plist>
		 
	'';

	installPhase = ''
		mkdir -p $out/Applications
		mv dhewm3.app $out/Applications/Doom\ 3.app
	'' + lib.optionalString (doom3-gamedata != null) ''
		cp -RH ${doom3-gamedata} $out/Applications/Doom\ 3.app/Contents/Resources/base
	'' + ''
		/usr/bin/codesign --remove-signature $out/Applications/Doom\ 3.app
		/usr/bin/codesign --sign - --deep $out/Applications/Doom\ 3.app
	'';
	dontFixup = true;

	passthru.updateScript = ''
		release=$(curl --silent https://api.github.com/repos/dhewm/dhewm3/releases/latest | jq --raw-output .name)
		version=''${release#dhewm3 }
		# fetch compiled version info from MacSourcePorts
		curl --silent 'https://api.github.com/repos/MacSourcePorts/MSPBuildSystem/releases?per_page=100' | \
			jq --raw-output '[.[] | select(.name | startswith("dhewm3"))][0] | .assets[0] | "\(.name) \(.browser_download_url) \(.digest)"' | \
			if read -r file url hash && test "$file" = "dhewm3-''${version}.dmg" ; then
				updateVersion version "$version"
				updateUrl url "$url"
				updateHash hash "$(nix hash convert --hash-algo sha256 --from base16 "''${hash#sha256:}")"
			else
				printWarning "MacSourcePorts does not have dhewm3 $version precompiled"
				printInfo 'https://www.macsourceports.com/game/doom3'
			fi
	'';
}
