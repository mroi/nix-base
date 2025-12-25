# Quake 2 game engine
{ lib, stdenvNoCC, fetchurl, undmg, writeText, quake2-gamedata ? null }:

stdenvNoCC.mkDerivation rec {
	pname = "quake2";
	version = "8.60";

	src = fetchurl {
		url = "https://github.com/MacSourcePorts/MSPBuildSystem/releases/download/yquake2_8.60/yquake2-8.60.dmg";
		hash = "sha256-NE03mAMeE+BTf56Ki8srFUj7lY/GrCB8LNgdzJ9fD8k=";
	};

	nativeBuildInputs = [ undmg ];
	sourceRoot = ".";
	__noChroot = true;

	patches = [
		(writeText "homedir-launch.patch" ''
			--- a/yquake2.app/Contents/Info.plist
			+++ b/yquake2.app/Contents/Info.plist
			@@ -3,7 +3,7 @@
			 <plist version="1.0">
			 <dict>
			     <key>CFBundleExecutable</key>
			-    <string>quake2</string>
			+    <string>quake2.sh</string>
			     <key>CFBundleIconFile</key>
			     <string>quake2</string>
			     <key>CFBundleIdentifier</key>
			--- /dev/null
			+++ b/yquake2.app/Contents/MacOS/quake2.sh
			@@ -0,0 +1,6 @@
			+#!/bin/sh
			+HOME="$HOME/Library/Application Support/Quake 2"
			+test -d "$HOME" || mkdir -p "$HOME"
			+export HOME
			+
			+exec "$(dirname "$0")/quake2" "$@"
		'')
		(writeText "app-store-category.patch" ''
			--- a/yquake2.app/Contents/Info.plist
			+++ b/yquake2.app/Contents/Info.plist
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
		mv yquake2.app $out/Applications/Quake\ 2.app
		chmod a+x $out/Applications/Quake\ 2.app/Contents/MacOS/quake2.sh
		rm -r $out/Applications/Quake\ 2.app/Contents/MacOS/{ctf,rogue,xatrix}
	'' + lib.optionalString (quake2-gamedata != null) ''
		cp -Rn ${quake2-gamedata}/* $out/Applications/Quake\ 2.app/Contents/MacOS/baseq2/
	'' + ''
		/usr/bin/codesign --remove-signature $out/Applications/Quake\ 2.app
		/usr/bin/codesign --remove-signature $out/Applications/Quake\ 2.app/Contents/MacOS/quake2
		/usr/bin/codesign --sign - --deep $out/Applications/Quake\ 2.app
	'';
	dontFixup = true;

	passthru.updateScript = ''
		tag=$(curl --silent https://api.github.com/repos/yquake2/yquake2/tags | jq --raw-output '.[0].name')
		version=$(echo "''${tag#QUAKE2_}" | tr _ .)
		# fetch compiled version info from MacSourcePorts
		curl --silent 'https://api.github.com/repos/MacSourcePorts/MSPBuildSystem/releases?per_page=100' | \
			jq --raw-output '[.[] | select(.name | startswith("yquake2"))][0] | .assets[0] | "\(.name) \(.browser_download_url) \(.digest)"' | \
			if read -r file url hash && test "$file" = "yquake2-''${version}.dmg" ; then
				updateVersion version "$version"
				updateUrl url "$url"
				updateHash hash "$(nix hash convert --hash-algo sha256 --from base16 "''${hash#sha256:}")"
			else
				printWarning "MacSourcePorts does not have vkQuake $version precompiled"
				printInfo 'https://www.macsourceports.com/game/quake'
			fi
	'';
}
