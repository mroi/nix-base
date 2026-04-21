# command line restore utility for the Arq backup tool
{ stdenv, fetchFromGitHub, fetchpatch, xcbuildHook, darwin, zlib }:

stdenv.mkDerivation {
	pname = "arq-restore";
	version = "5.7-unstable-2026-04-13";

	src = fetchFromGitHub {
		owner = "arqbackup";
		repo = "arq_restore";
		rev = "0911ce278a2311c3ee16746d2e3f6a5ab2be0d35";
		hash = "sha256-Tw/iFXFLxa0D5dVBGst9jT9eZ3mN/Zz3xTPzusRGJUU=";
	};
	patches = fetchpatch {
		url = "https://github.com/arqbackup/arq_restore/pull/52.diff";
		hash = "sha256-kaJe1DS+Nuje9yqnsUD0B76KNAI02Y7G3M+SPY8+TVs=";
	};

	nativeBuildInputs = [ xcbuildHook ];
	buildInputs = [ darwin.ICU zlib ];
	xcbuildFlags = "GCC_TREAT_WARNINGS_AS_ERRORS=NO";

	installPhase = ''
		mkdir -p $out/bin
		cp Products/Release/arq_restore $out/bin
	'';

	passthru.updateScript = "nixUpdate --version branch";
}
