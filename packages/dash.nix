# Dash documentation browser
{ lib, fetchzip }:

let
	major = "7";
	url = "https://kapeli.com/downloads/v${major}/Dash.zip";

in fetchzip rec {
	inherit url;

	pname = "dash";
	version = "7.3.5";

	hash  = "sha256-z6OYLYjjDbAUfdG45BvWtC+1y29kLG0K4Ns7UN3herk=";
	stripRoot = false;

	postFetch = ''
		rm -rf __MACOSX
		mkdir $out/Applications
		mv Dash.app $out/Applications/
	'';

	passthru.updateScript = ''
		version=$(curl --silent https://kapeli.com/Dash${major}.xml | xmllint --xpath 'string(/rss/channel/item/enclosure/@*[local-name()="shortVersionString"])' -)
		updateVersion version "$version"
		if didUpdate ; then
			curl --silent --output Dash.zip '${url}'
			mkdir root
			unzip -q -d root/Applications Dash.zip
			rm -rf root/Applications/__MACOSX
			if checkSig root/Applications/Dash.app JP58VMK957 ; then
				updateHash hash "$(nix hash path root)"
			else
				updateHash hash ${lib.fakeHash}
			fi
			rm -r root Dash.zip
		fi
	'';
}
