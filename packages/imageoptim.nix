# ImageOptim image optimizer
{ lib, stdenvNoCC, fetchzip }:

stdenvNoCC.mkDerivation rec {
	pname = "imageoptim";
	version = "1.9.3";

	src = fetchzip {
		url = "https://imageoptim.com/ImageOptim${version}.tar.xz";
		hash  = "sha256-DTgGypH+lyc4T+WqSijEute5meNeZ8l2O1BPYm1rL+M=";
		stripRoot = false;
	};

	__noChroot = true;
	installPhase = ''
		mkdir -p $out/Applications
		mv ImageOptim.app $out/Applications/
		/usr/bin/ditto -xz ${./imageoptim-icon.cpgz} $out/Applications/ImageOptim.app/
		unset DEVELOPER_DIR  # FIXME: remove when https://github.com/NixOS/nixpkgs/issues/371465 is resolved
		/usr/bin/SetFile -a C $out/Applications/ImageOptim.app
	'';
	dontFixup = true;

	passthru.updateScript = ''
		version=$(curl --silent https://imageoptim.com/appcast.xml | xmllint --xpath 'string(/rss/channel/item/enclosure/@*[local-name()="version"])' -)
		updateVersion version "$version"
		if didUpdate ; then
			curl --silent --output ImageOptim.tar.xz "https://imageoptim.com/ImageOptim''${version}.tar.xz"
			mkdir root
			tar -xf ImageOptim.tar.xz --directory root
			if checkSig root/ImageOptim.app 59KZTZA4XR ; then
				updateHash hash "$(nix hash path root)"
			else
				updateHash hash ${lib.fakeHash}
			fi
			rm -r root ImageOptim.tar.xz
		fi
	'';
}
