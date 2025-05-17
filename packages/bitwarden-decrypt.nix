# tool to decrypt Bitwarden exports
{ stdenvNoCC, python3, fetchFromGitHub, writeText }:

let
	python = python3.withPackages (pkgs: [ pkgs.cryptography pkgs.argon2-cffi ]);

in stdenvNoCC.mkDerivation {
	pname = "bitwarden-decrypt";
	version = "1.6-unstable-2024-08-31";

	src = fetchFromGitHub {
		owner = "GurpreetKang";
		repo = "BitwardenDecrypt";
		rev = "227a12224ba7aa56279c6e27ef19f531d1fc4dc7";
		hash = "sha256-utGTqN6Ns37BwEZS8EfDRK9dtto9cbvTWrI/Hl47wak=";
	};

	# see https://github.com/GurpreetKang/BitwardenDecrypt/pull/33
	patches = writeText "encrypted-json-fix.patch" ''
		--- a/BitwardenDecrypt.py
		+++ b/BitwardenDecrypt.py
		@@ -356,7 +356,9 @@
		         # Email address is used as the salt in data.json, in password protected excrypted json exports there is an explicit salt key/value (and no email).
		         email = datafile.get("salt")
		         kdfIterations = int(datafile.get("kdfIterations"))
		-        kdfType = 0         
		+        kdfType = int(datafile.get("kdfType"))
		+        kdfMemory = int(datafile.get("kdfMemory"))
		+        kdfParallelism = int(datafile.get("kdfParallelism"))
		         encKey = datafile.get("encKeyValidation_DO_NOT_EDIT")
		 
		     # Check if data.json is 2024/new/old format.
		@@ -794,7 +796,7 @@
		             print(f"ERROR: Writing to {options.outputfile}")
		 
		     else:
		-        print(decryptedJSON.encode("utf-8"))
		+        print(decryptedJSON)
		 
		 
		 if __name__ == "__main__":
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
