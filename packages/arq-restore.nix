# command line restore utility for the Arq backup tool
{ stdenv, fetchFromGitHub, fetchpatch, xcbuildHook, darwin, zlib }:

stdenv.mkDerivation {
	pname = "arq-restore";
	version = "5.7-unstable-2026-03-19";

	src = fetchFromGitHub {
		owner = "arqbackup";
		repo = "arq_restore";
		rev = "939b61f7960cdd3b4c85e751d077768c193562af";
		hash = "sha256-L+rJ48AGb+tpJKAoID6bPThg/Gpq7dHlaO0vvuGsBBI=";
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
