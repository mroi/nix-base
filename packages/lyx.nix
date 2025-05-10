# LyX document editor for LaTeX
{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
	pname = "lyx";
	version = "2.4.3";

	src = fetchurl {
		url = "https://ftp.lip6.fr/pub/lyx/bin/${version}/LyX-${version}+qt5-x86_64-arm64-cocoa.dmg";
		hash  = "sha256-Pp2EYiFl5RnO6PTW9NDVi+TtyNrx2B7aHBtrOt3pq0s=";
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
		unset DEVELOPER_DIR  # FIXME: remove when https://github.com/NixOS/nixpkgs/issues/371465 is resolved
		/usr/bin/SetFile -a C $out/Applications/LyX.app
	'';
	dontFixup = true;

	passthru.updateScript = ''
		dir=$(curl --silent https://ftp.lip6.fr/pub/lyx/bin/ | xmllint --html --xpath '//a/text()' - | sort --version-sort | tail -n1)
		version=''${dir%/}
		updateVersion version "$version"
		if didUpdate ; then
			hash=$(curl --silent "https://ftp.lip6.fr/pub/lyx/bin/$version/LyX-$version+qt5-x86_64-arm64-cocoa.dmg" | nix hash file /dev/stdin)
			updateHash hash "$hash"
		fi
	'';
}
