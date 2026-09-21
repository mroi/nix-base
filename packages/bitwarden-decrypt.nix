# tool to decrypt Bitwarden exports
{ stdenvNoCC, python3, fetchFromGitHub, writeText }:

let
	python = python3.withPackages (pkgs: [ pkgs.cryptography pkgs.argon2-cffi ]);

in stdenvNoCC.mkDerivation {
	pname = "bitwarden-decrypt";
	version = "1.6-unstable-2026-09-18";

	src = fetchFromGitHub {
		owner = "GurpreetKang";
		repo = "BitwardenDecrypt";
		rev = "f6c7a9b7256c787d004ca34510e35805086d80a3";
		hash = "sha256-6fuRXZAgYWiNE+JNO7TyR6VS4BiM4D+K+mzM9HuQPRM=";
	};

	# see https://github.com/GurpreetKang/BitwardenDecrypt/pull/33
	patches = writeText "encrypted-json-fix.patch" ''
		--- a/BitwardenDecrypt.py
		+++ b/BitwardenDecrypt.py
		@@ -368,7 +368,9 @@
		         # Email address is used as the salt in data.json, in password protected excrypted json exports there is an explicit salt key/value (and no email).
		         email = datafile.get("salt")
		         kdfIterations = int(datafile.get("kdfIterations"))
		-        kdfType = 0         
		+        kdfType = int(datafile.get("kdfType"))
		+        kdfMemory = int(datafile.get("kdfMemory"))
		+        kdfParallelism = int(datafile.get("kdfParallelism"))
		         encKey = datafile.get("encKeyValidation_DO_NOT_EDIT")
		 
		     # Check if data.json is 2024/new/old format.
	'';

	installPhase = ''
		mkdir -p $out/share $out/bin
		cp *.py $out/share
		cat <<- EOF > $out/bin/bitwarden-decrypt
			#!/bin/sh
			exec ${python}/bin/python $out/share/BitwardenDecrypt.py "\$@"
		EOF
		chmod a+x $out/bin/bitwarden-decrypt
	'';

	passthru.updateScript = "nixUpdate --version branch";
}
