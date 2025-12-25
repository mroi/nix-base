# VICE emulator for Commodore home computers
{ lib, stdenvNoCC, fetchurl, undmg }:

stdenvNoCC.mkDerivation rec {
	pname = "vice";
	version = "3.10";

	src = fetchurl {
		url = "mirror://sourceforge/vice-emu/${pname}-arm64-gtk3-${version}.dmg";
		hash  = "sha256-YXB+t+XSmTmDMucDLjm42ZnpUZFpfg1CrlP5RH+0IOQ=";
	};

	nativeBuildInputs = [ undmg ];
	sourceRoot = ".";
	__noChroot = true;

	installPhase = ''
		mkdir -p $out/Applications
		mv ${pname}-arm64-gtk3-${version}/VICE.app $out/Applications/
		/usr/bin/ditto -xz ${./vice-icon.cpgz} $out/Applications/VICE.app/
		/usr/bin/SetFile -a C $out/Applications/VICE.app
	'';
	dontFixup = true;

	passthru.updateScript = ''
		latest=$(curl --silent 'https://sourceforge.net/projects/vice-emu/rss?path=/releases/binaries/macosx' | xmllint --xpath 'string(/rss/channel/item[contains(title/text(), "arm64-gtk3")]/title/text())' -)
		file=''${latest#/releases/binaries/macosx/${pname}-arm64-gtk3-}
		version=''${file%.dmg}
		updateVersion version "$version"
		if didUpdate ; then
			download=https://downloads.sourceforge.net/vice-emu/${pname}-arm64-gtk3-''${version}.dmg
			hash=$(curl --silent --location "$download" | nix hash file /dev/stdin)
			updateHash hash "$hash"
		fi
	'';
}
