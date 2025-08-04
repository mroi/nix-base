# Doom and Doom 2 game engine
{ lib, stdenvNoCC, fetchzip, doom1-gamedata ? null, doom2-gamedata ? null }:

stdenvNoCC.mkDerivation rec {
	pname = "doom";
	version = "g4.14.2";

	src = let
		dashedVersion = lib.replaceString "." "-" (lib.removePrefix "g" version);
	in fetchzip {
		url = "https://github.com/ZDoom/gzdoom/releases/download/${version}/gzdoom-${dashedVersion}-macos.zip";
		hash = "sha256-1sSGgTpOttA6j1Q7KzpqoUOAiY0kYWUQdwA5HYwlo/0=";
		stripRoot = false;
	};

	__noChroot = true;

	installPhase = ''
		/usr/sbin/dot_clean GZDoom.app
		mkdir -p $out/Applications
		mv GZDoom.app $out/Applications/Doom.app
		cp ${./doom-icon.icns} $out/Applications/Doom.app/Contents/Resources/zdoom.icns
	'' + lib.optionalString (doom1-gamedata != null) ''
		cp ${doom1-gamedata} $out/Applications/Doom.app/Contents/Resources/doom.wad
	'' + lib.optionalString (doom2-gamedata != null) ''
		cp ${doom2-gamedata} $out/Applications/Doom.app/Contents/Resources/doom2.wad
	'' + ''
		/usr/bin/codesign --remove-signature $out/Applications/Doom.app
		/usr/bin/codesign --sign - --deep $out/Applications/Doom.app
	'';
	dontFixup = true;

	passthru.updateScript = ''
		release=$(curl --silent https://api.github.com/repos/ZDoom/gzdoom/releases/latest | jq --raw-output .name)
		version=''${release#GZDoom }
		updateVersion version "$version"
		if didUpdate ; then
			dashedVersion=$(echo "''${version#g}" | tr . -)
			curl --silent --location --output GZDoom.zip "https://github.com/ZDoom/gzdoom/releases/download/''${version}/gzdoom-''${dashedVersion}-macos.zip"
			mkdir root
			unzip -q -d root GZDoom.zip
			# merge Apple double files on a copy of the app, otherwise signature checking fails
			cp -Rl root/GZDoom.app ./
			if $isDarwin && dot_clean GZDoom.app && checkSig GZDoom.app MHNLSTH76Z ; then
				updateHash hash "$(nix hash path root)"
			else
				updateHash hash ${lib.fakeHash}
			fi
			rm -r root GZDoom.app GZDoom.zip
		fi
	'';
}
