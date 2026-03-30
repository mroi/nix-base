# Blender 3D creation suite
{ lib, stdenvNoCC, fetchurl, undmg }:

stdenvNoCC.mkDerivation rec {
	pname = "blender";
	version = "5.1.0";

	src = fetchurl {
		url = let
			series = lib.head (lib.match "([0-9]+\.[0-9]+).*" version);
		in "https://download.blender.org/release/Blender${series}/blender-${version}-macos-arm64.dmg";
		hash  = "sha256-6+2g27f78G88vPWMETl1Ud50XxF3rP4+IzGsDU2QGZY=";
	};

	nativeBuildInputs = [ undmg ];
	sourceRoot = ".";

	installPhase = ''
		mkdir -p $out/Applications
		mv Blender.app $out/Applications/
	'';
	dontFixup = true;

	passthru.updateScript = ''
		tag=$(curl --silent https://api.github.com/repos/blender/blender/tags | jq --raw-output '.[0].name')
		version=''${tag#v}
		updateVersion version "$version"
		if didUpdate ; then
			if test "$(echo "$version" | fgrep -o . | wc -l)" -eq 2 ; then
				series=''${version%.*}
			else
				series=$version
			fi
			download=https://download.blender.org/release/Blender''${series}/blender-''${version}-macos-arm64.dmg
			hash=$(curl --silent --location "$download" | nix hash file /dev/stdin)
			updateHash hash "$hash"
		fi
	'';
}
