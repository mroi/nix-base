# GitUp git frontend
{ lib, fetchzip }:

fetchzip rec {
	pname = "gitup";
	version = "1.5.0";

	url = "https://github.com/git-up/GitUp/releases/download/v${version}/GitUp.zip";
	hash = "sha256-Mx0MdFknkFd4GTjktipaZz2lPf3VnymvGeQ4cO/zrlU=";
	stripRoot = false;

	postFetch = ''
		rm -rf __MACOSX
		mkdir $out/Applications
		mv GitUp.app $out/Applications/
	'';

	passthru.updateScript = ''
		release=$(curl --silent https://api.github.com/repos/git-up/GitUp/releases/latest | jq --raw-output .tag_name)
		version=''${release#v}
		updateVersion version "$version"
		if didUpdate ; then
			curl --silent --location --output GitUp.zip "https://github.com/git-up/GitUp/releases/download/v''${version}/GitUp.zip"
			mkdir root
			unzip -q -d root/Applications GitUp.zip
			rm -rf root/Applications/__MACOSX
			if $isDarwin && checkSig root/Applications/GitUp.app FP44AY6HHW ; then
				updateHash hash "$(nix hash path root)"
			else
				updateHash hash ${lib.fakeHash}
			fi
			rm -r root GitUp.zip
		fi
	'';
}
