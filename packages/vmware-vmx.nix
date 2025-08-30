# tool to decrypt and encrypt VMware vmx files
{ stdenvNoCC, python3, fetchFromGitHub }:

let
	python = python3.withPackages (pkgs: [ pkgs.pycryptodome ]);

in stdenvNoCC.mkDerivation {
	pname = "vmware-vmx";
	version = "1.0.7-unstable-2025-08-19";

	src = fetchFromGitHub {
		owner = "RF3";
		repo = "VMwareVMX";
		rev = "7a514f040263b60e9e471248fd56afe0ed190a8a";
		hash = "sha256-luZH7KV3mmCGo2uJnaZNC2RJCMgtj6NGXJhsjA20Ee8=";
	};

	installPhase = ''
		mkdir -p $out/share $out/bin
		cp *.py $out/share
		cat <<- EOF > $out/bin/vmware-vmx
			#!/bin/sh
			exec ${python}/bin/python $out/share/main.py "\$@"
		EOF
		chmod a+x $out/bin/vmware-vmx
	'';

	passthru.updateScript = "nixUpdate --version branch";
}
