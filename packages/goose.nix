# Goose AI agent
{ lib, fetchzip }:

fetchzip rec {
	pname = "goose";
	version = "1.48.0";

	url = "https://github.com/aaif-goose/goose/releases/download/v${version}/Goose.zip";
	hash = "sha256-f3pn7+Css7VAiqFsw6PUPd9qdWpm2OI0LR2vncCHLgM=";
	stripRoot = false;

	postFetch = ''
		rm -rf __MACOSX
		mkdir -p $out/Applications
		mv Goose.app $out/Applications/
	'';

	passthru.updateScript = ''
		release=$(curl --silent https://api.github.com/repos/aaif-goose/goose/releases/latest | jq --raw-output .name)
		version=''${release#v}
		updateVersion version "$version"
		if didUpdate ; then
			curl --silent --location --output Goose.zip "https://github.com/aaif-goose/goose/releases/download/v''${version}/Goose.zip"
			mkdir root
			unzip -q -d root/Applications Goose.zip
			rm -rf root/Applications/__MACOSX
			if $isDarwin && checkSig root/Applications/Goose.app 5N2JF58U87 ; then
				updateHash hash "$(nix hash path root)"
			else
				updateHash hash ${lib.fakeHash}
			fi
			rm -r root Goose.zip
		fi
	'';
}
