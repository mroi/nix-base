# command line restore utility for the Arq backup tool
{ lib, system, path, stdenv, fetchFromGitHub, xcbuildHook, darwin, zlib }:

let
	openssl_1_1 = (import path {
		config.permittedInsecurePackages = [ "openssl-1.1.1w" ];
		inherit system;
	}).openssl_1_1;

in stdenv.mkDerivation {
	pname = "arq-restore";
	version = "5.7";

	src = fetchFromGitHub {
		owner = "arqbackup";
		repo = "arq_restore";
		# curl https://api.github.com/repos/arqbackup/arq_restore/git/refs/heads/master
		rev = "d4a3d0e14c51695fb0e38c78804859a856eca3bc";
		sha256 = "0np42gri9rjaa5xf2vh5ppg53dw616i8qls83c8588pb5x0nlg12";
	};

	nativeBuildInputs = [ xcbuildHook ];
	buildInputs = [ darwin.apple_sdk.frameworks.Cocoa darwin.ICU openssl_1_1 zlib ];
	xcbuildFlags = "GCC_TREAT_WARNINGS_AS_ERRORS=NO";

	patches = [ ./arq-restore-openssl.patch ];

	installPhase = ''
		mkdir -p $out/bin
		cp Products/Release/arq_restore $out/bin
	'';

	meta = {
		description = "command-line utility for restoring from Arq backups";
		homepage    = "https://www.arqbackup.com";
		platforms   = lib.platforms.darwin;
		maintainers = [{
			email = "reactorcontrol@icloud.com";
			github = "mroi";
			name = "Michael Roitzsch";
		}];
	};
}
