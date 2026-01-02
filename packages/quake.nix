# Quake game engine
{ lib, stdenvNoCC, fetchurl, undmg, writeText, quake1-gamedata ? null }:

stdenvNoCC.mkDerivation rec {
	pname = "quake";
	version = "1.33.1";

	src = fetchurl {
		url = "https://github.com/MacSourcePorts/MSPBuildSystem/releases/download/vkQuake_1.33.1/vkQuake-1.33.1.dmg";
		hash = "sha256-uNpT0Bgr8rF1NMyh5zR0+MYqvIiUM76XhGF+y6c35RI=";
	};

	nativeBuildInputs = [ undmg ];
	sourceRoot = ".";
	__noChroot = true;

	patches = [
		(writeText "basedir-launch.patch" ''
			--- a/vkQuake.app/Contents/Info.plist
			+++ b/vkQuake.app/Contents/Info.plist
			@@ -3,7 +3,7 @@
			 <plist version="1.0">
			 <dict>
			     <key>CFBundleExecutable</key>
			-    <string>vkquake</string>
			+    <string>vkquake.sh</string>
			     <key>CFBundleIconFile</key>
			     <string>vkquake</string>
			     <key>CFBundleIdentifier</key>
			--- /dev/null	2025-12-24 14:28:16
			+++ b/vkQuake.app/Contents/MacOS/vkquake.sh
			@@ -0,0 +1,4 @@
			+#!/bin/sh
			+dir=$(cd "$(dirname "$0")"; pwd)
			+"$dir/vkquake" -basedir "$HOME/Library/Application Support/Quake/"
			+rm -f "$dir/../../../history.txt"
		'')
		(writeText "app-store-category.patch" ''
			--- a/vkQuake.app/Contents/Info.plist
			+++ b/vkQuake.app/Contents/Info.plist
			@@ -25,7 +25,7 @@
			     <key>NSHighResolutionCapable</key>
			     <true/>
			     <key>LSApplicationCategoryType</key>
			-    <string>public.app-category.games</string>
			+    <string>public.app-category.action-games</string>
			 </dict>
			 </plist>
			 
		'')
	];

	installPhase = ''
		mkdir -p $out/Applications
		mv vkQuake.app $out/Applications/Quake.app
		chmod a+x $out/Applications/Quake.app/Contents/MacOS/vkquake.sh
	'' + lib.optionalString (quake1-gamedata != null) ''
		cp -RH ${quake1-gamedata} $out/Applications/Quake.app/Contents/Resources/id1
	'' + ''
		/usr/bin/codesign --remove-signature $out/Applications/Quake.app
		/usr/bin/codesign --remove-signature $out/Applications/Quake.app/Contents/MacOS/vkquake
		/usr/bin/codesign --sign - --deep $out/Applications/Quake.app
	'';
	dontFixup = true;

	passthru.updateScript = ''
		version=$(curl --silent https://api.github.com/repos/Novum/vkQuake/releases/latest | jq --raw-output .tag_name)
		# fetch compiled version info from MacSourcePorts
		curl --silent 'https://api.github.com/repos/MacSourcePorts/MSPBuildSystem/releases?per_page=100' | \
			jq --raw-output '[.[] | select(.name | startswith("vkQuake"))][0] | .assets[0] | "\(.name) \(.browser_download_url) \(.digest)"' | \
			if read -r file url hash && test "$file" = "vkQuake-''${version}.dmg" ; then
				updateVersion version "$version"
				updateUrl url "$url"
				updateHash hash "$(nix hash convert --hash-algo sha256 --from base16 "''${hash#sha256:}")"
			else
				printWarning "MacSourcePorts does not have vkQuake $version precompiled"
				printInfo 'https://www.macsourceports.com/game/quake'
			fi
	'';
}
