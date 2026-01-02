# Dash documentation browser
{ lib, fetchzip }:

let
	version = "8.0.2";
	major = lib.head (lib.splitVersion version);
	url = "https://kapeli.com/downloads/v${major}/Dash.zip";

in fetchzip rec {
	inherit version url;

	pname = "dash";

	hash  = "sha256-xgqUY3U+jVkaWC3+SjcIgUqX4mmFZ3z6mvfdYWe1h94=";
	stripRoot = false;

	postFetch = ''
		rm -rf __MACOSX
		mkdir $out/Applications
		mv Dash.app $out/Applications/
	'';

	passthru.updateScript = let
		major = "7";  # weird, but the RSS feed version does not seem to follow the package version
	in ''
		version=$(curl --silent https://kapeli.com/Dash${major}.xml | xmllint --xpath 'string(/rss/channel/item/enclosure/@*[local-name()="shortVersionString"])' -)
		updateVersion version "$version"
		if didUpdate ; then
			curl --silent --output Dash.zip '${url}'
			mkdir root
			unzip -q -d root/Applications Dash.zip
			rm -rf root/Applications/__MACOSX
			if $isDarwin && checkSig root/Applications/Dash.app JP58VMK957 ; then
				updateHash hash "$(nix hash path root)"
			else
				updateHash hash ${lib.fakeHash}
			fi
			rm -r root Dash.zip
		fi
	'';
}
