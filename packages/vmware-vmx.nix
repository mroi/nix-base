# tool to decrypt and encrypt VMware vmx files
{ stdenvNoCC, python3, fetchFromGitHub }:

let
	python = python3.withPackages (pkgs: [ pkgs.pycryptodome ]);

in stdenvNoCC.mkDerivation {
	pname = "vmware-vmx";
	version = "1.0.7-unstable-2024-02-10";

	src = fetchFromGitHub {
		owner = "RF3";
		repo = "VMwareVMX";
		rev = "0cdfe49c486fd41de73dd8decb2b4a83791ec28f";
		hash = "sha256-cIA0qLwxuBtEyRnWug/pLtm2PaCLWruuvp9HQSwBy0M=";
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
