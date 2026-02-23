# Inkscape vector image editor
{ stdenvNoCC, fetchurl, undmg }:

stdenvNoCC.mkDerivation {
	pname = "inkscape";
	version = "1.4.3";

	src = fetchurl {
		url = "https://inkscape.org/gallery/item/58922/Inkscape-1.4.3_arm64.dmg";
		hash  = "sha256-9Kqcmy4G20Msb4GklK2apZuHy32VOc1+b2AAACy57f8=";
	};

	nativeBuildInputs = [ undmg ];
	sourceRoot = ".";

	installPhase = ''
		mkdir -p $out/Applications
		mv Inkscape.app $out/Applications/
	'';
	dontFixup = true;

	passthru.updateScript = ''
		redirect=$(curl --silent --request HEAD --write-out '%header{location}' https://inkscape.org/release/)
		version=''${redirect#/release/inkscape-}
		version=''${version%/}
		if test "$(echo "$version" | fgrep -o . | wc -l)" -eq 1 ; then version=$version.0 ; fi
		updateVersion version "$version"
		if didUpdate ; then
			download=https://inkscape.org$(curl --silent https://inkscape.org/release/inkscape-$version/mac-os-x/dmg-arm64/dl/ | xmllint --html --xpath 'string((/html/body//a/@href[contains(.,".dmg")])[1])' - 2> /dev/null)
			updateUrl url "$download"
			hash=$(curl --silent --location "$download" | nix hash file /dev/stdin)
			updateHash hash "$hash"
		fi
	'';
}
