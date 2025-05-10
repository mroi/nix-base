# Veusz scientific plotting application
{ stdenv, fetchurl, _7zz }:

stdenv.mkDerivation rec {
	pname = "veusz";
	version = "3.6.2";

	src = fetchurl {
		url = "https://github.com/veusz/veusz/releases/download/veusz-${version}/veusz-${version}-AppleOSX.dmg";
		hash  = "sha256-zAnXSRxkJZtbTgYARxnDUPfppaRyFzzyk8itBnBWwAI=";
	};

	nativeBuildInputs = [ _7zz ];
	sourceRoot = ".";
	__noChroot = true;

	installPhase = ''
		mkdir -p $out/Applications
		mv Veusz.app $out/Applications/
		/usr/bin/ditto -xz ${./veusz-icon.cpgz} $out/Applications/Veusz.app/
		unset DEVELOPER_DIR  # FIXME: remove when https://github.com/NixOS/nixpkgs/issues/371465 is resolved
		/usr/bin/SetFile -a C $out/Applications/Veusz.app
	'';
	dontFixup = true;

	passthru.updateScript = ''
		release=$(curl --silent https://api.github.com/repos/veusz/veusz/releases/latest | jq --raw-output .name)
		version=''${release#Veusz }
		updateVersion version "$version"
		if didUpdate ; then
			curl --silent --location --output Veusz.dmg "https://github.com/veusz/veusz/releases/download/veusz-''${version}/veusz-''${version}-AppleOSX.dmg"
			updateHash hash "$(nix hash file Veusz.dmg)"
			rm Veusz.dmg
		fi
	'';
}
