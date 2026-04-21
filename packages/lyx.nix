# LyX document editor for LaTeX
{ stdenvNoCC, fetchurl }:

stdenvNoCC.mkDerivation rec {
	pname = "lyx";
	version = "2.5.1";

	src = fetchurl {
		url = "https://lyx.mirror.garr.it/bin/${version}/LyX-${version}+qt6-x86_64-arm64-cocoa.dmg";
		hash  = "sha256-HDqMv3yB6dBrU+G6KREZNjiBs0dyKBbPU7a5ErNYk3A=";
	};

	__noChroot = true;
	unpackPhase = ''
		mkdir dmg
		/usr/bin/hdiutil attach $src -readonly -mountpoint $PWD/dmg
		cp -r dmg/LyX.app ./
		/usr/bin/hdiutil detach $PWD/dmg
	'';

	installPhase = ''
		mkdir -p $out/Applications
		mv LyX.app $out/Applications/
		/usr/bin/ditto -xz ${./lyx-icon.cpgz} $out/Applications/LyX.app/
		/usr/bin/SetFile -a C $out/Applications/LyX.app
	'';
	dontFixup = true;

	passthru.updateScript = ''
		dir=$(curl --silent https://lyx.mirror.garr.it/bin/ | xmllint --html --xpath '//a/text()' - | sort --version-sort | tail -n1)
		version=''${dir%/}
		updateVersion version "$version"
		if didUpdate ; then
			hash=$(curl --silent "https://lyx.mirror.garr.it/bin/$version/LyX-$version+qt6-x86_64-arm64-cocoa.dmg" | nix hash file /dev/stdin)
			updateHash hash "$hash"
		fi
	'';
}
