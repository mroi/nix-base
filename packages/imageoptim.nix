# ImageOptim image optimizer
{ lib, fetchzip }:

fetchzip rec {
	pname = "imageoptim";
	version = "1.9.3";

	url = "https://imageoptim.com/ImageOptim${version}.tar.xz";
	hash = "sha256-++nXdYtWSFSh1rW07ubQIiayOVvNCiDGEl9u7ZAdK9o=";
	stripRoot = false;

	postFetch = ''
		mkdir -p $out/Applications
		mv ImageOptim.app $out/Applications/
	'';

	passthru.updateScript = ''
		version=$(curl --silent https://imageoptim.com/appcast.xml | xmllint --xpath 'string(/rss/channel/item/enclosure/@*[local-name()="version"])' -)
		updateVersion version "$version"
		if didUpdate ; then
			curl --silent --output ImageOptim.tar.xz "https://imageoptim.com/ImageOptim''${version}.tar.xz"
			mkdir -p root/Applications
			tar -xf ImageOptim.tar.xz --directory root/Applications
			if $isDarwin && checkSig root/ImageOptim.app 59KZTZA4XR ; then
				updateHash hash "$(nix hash path root)"
			else
				updateHash hash ${lib.fakeHash}
			fi
			rm -r root ImageOptim.tar.xz
		fi
	'';
}
