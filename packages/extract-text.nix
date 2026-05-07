# extract raw text from PDFs, RTF, images
{ stdenv, swift }:

stdenv.mkDerivation {
	name = "extract-text";

	src = ./extract-text.swift;
	dontUnpack = true;

	nativeBuildInputs = [ swift ];
	buildPhase = "swiftc -o $name $src";

	installPhase = ''
		mkdir -p $out/bin
		cp $name $out/bin/
	'';
}
