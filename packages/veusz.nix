# Veusz scientific plotting application
{ stdenvNoCC, fetchurl, _7zz }:

stdenvNoCC.mkDerivation rec {
	pname = "veusz";
	version = "4.2.1";

	src = fetchurl {
		url = "https://github.com/veusz/veusz/releases/download/veusz-${version}/veusz-${version}-AppleOSX-arm.dmg";
		hash = "sha256-/PMZPgpg82W6n4KrHcY0JX5Z7jx1jMOogubB62CGcwA=";
	};

	nativeBuildInputs = [ _7zz ];
	sourceRoot = ".";
	unpackPhase = "7zz x -snld20 $src";
	__noChroot = true;

	installPhase = ''
		mkdir -p $out/Applications
		mv Veusz.app $out/Applications/
		/usr/bin/ditto -xz ${./veusz-icon.cpgz} $out/Applications/Veusz.app/
		/usr/bin/SetFile -a C $out/Applications/Veusz.app
	'';
	dontFixup = true;

	passthru.updateScript = ''
		release=$(curl --silent https://api.github.com/repos/veusz/veusz/releases/latest | jq --raw-output .name)
		version=''${release#Veusz }
		updateVersion version "$version"
		if didUpdate ; then
			curl --silent --location --output Veusz.dmg "https://github.com/veusz/veusz/releases/download/veusz-''${version}/veusz-''${version}-AppleOSX-arm.dmg"
			updateHash hash "$(nix hash file Veusz.dmg)"
			rm Veusz.dmg
		fi
	'';
}
