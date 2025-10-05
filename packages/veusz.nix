# Veusz scientific plotting application
{ stdenvNoCC, fetchurl, _7zz }:

stdenvNoCC.mkDerivation rec {
	pname = "veusz";
	version = "4.2";

	src = let
		aarch64-hash = "sha256-DP7wAibVhjGyfPzA4wD48S0rsWqVNJdX6S/pAI/E//8=";
		x86_64-hash = "sha256-HCPThezAIeY/wr+EWaFzrKNoSBZ2PdMr32H5DO1T1/M=";
	in builtins.getAttr stdenvNoCC.system {
		aarch64-darwin = fetchurl {
			url = "https://github.com/veusz/veusz/releases/download/veusz-${version}/veusz-${version}-AppleOSX-arm.dmg";
			hash = aarch64-hash;
		};
		x86_64-darwin = fetchurl {
			url = "https://github.com/veusz/veusz/releases/download/veusz-${version}/veusz-${version}-AppleOSX-x86_64.dmg";
			hash = x86_64-hash;
		};
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
			updateHash aarch64-hash "$(nix hash file Veusz.dmg)"
			curl --silent --location --output Veusz.dmg "https://github.com/veusz/veusz/releases/download/veusz-''${version}/veusz-''${version}-AppleOSX-x86_64.dmg"
			updateHash x86_64-hash "$(nix hash file Veusz.dmg)"
			rm Veusz.dmg
		fi
	'';
}
