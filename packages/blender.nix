# Blender 3D creation suite
{ lib, stdenvNoCC, fetchurl, undmg }:

stdenvNoCC.mkDerivation rec {
	pname = "blender";
	version = "4.5.3";

	src = fetchurl {
		url = let
			series = lib.head (lib.match "([0-9]+\.[0-9]+).*" version);
		in "https://download.blender.org/release/Blender${series}/blender-${version}-macos-arm64.dmg";
		hash  = "sha256-c+qEEFO1VAS7OnGpoiNm8fiCF4f+XImfi1Wn//kp0Bs=";
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
