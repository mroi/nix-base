# Inkscape vector image editor
{ stdenvNoCC, fetchurl, undmg }:

stdenvNoCC.mkDerivation {
	pname = "inkscape";
	version = "1.4.0";

	src = fetchurl {
		url = "https://inkscape.org/gallery/item/53700/Inkscape-1.4.028868_arm64.dmg";
		hash  = "sha256-wtiYCa2NhQIed4TnLiiu4iMbC4Z17D7ePm+58f/ttLM=";
	};

	nativeBuildInputs = [ undmg ];
	sourceRoot = ".";

	installPhase = ''
		mkdir -p $out/Applications
		mv Inkscape.app $out/Applications/
	'';
	dontFixup = true;

	passthru.updateScript = ''
		release=$(curl --silent https://gitlab.com/api/v4/projects/3472737/releases | jq --raw-output '.[0].name')
		version=''${release#Inkscape }
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
