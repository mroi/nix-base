# command line restore utility for the Arq backup tool
{ lib, system, path, stdenv, fetchFromGitHub, xcbuildHook, darwin, zlib }:

let
	openssl_1_1 = (import path {
		config.permittedInsecurePackages = [ "openssl-1.1.1w" ];
		inherit system;
	}).openssl_1_1;

in stdenv.mkDerivation {
	pname = "arq-restore";
	version = "5.7-unstable-2020-12-14";

	src = fetchFromGitHub {
		owner = "arqbackup";
		repo = "arq_restore";
		rev = "d4a3d0e14c51695fb0e38c78804859a856eca3bc";
		hash = "sha256-IjxqQS/rIlQQG0hTjKIJhrdR3r0FbuF6UUrmFPMT5Fo=";
	};

	nativeBuildInputs = [ xcbuildHook ];
	buildInputs = [ darwin.ICU openssl_1_1 zlib ];
	xcbuildFlags = "GCC_TREAT_WARNINGS_AS_ERRORS=NO";

	patches = [ ./arq-restore-openssl.patch ];

	installPhase = ''
		mkdir -p $out/bin
		cp Products/Release/arq_restore $out/bin
	'';

	passthru.updateScript = "nixUpdate --version branch";
}
