# tool to decrypt and encrypt VMware vmx files
{ stdenvNoCC, python3, fetchFromGitHub, fetchpatch }:

let
	python = python3.withPackages (pkgs: [ pkgs.pycryptodome ]);

in stdenvNoCC.mkDerivation {
	name = "vmware-vmx";

	src = fetchFromGitHub {
		owner = "RF3";
		repo = "VMwareVMX";
		# curl https://api.github.com/repos/RF3/VMwareVMX/git/refs/heads/master
		rev = "0cdfe49c486fd41de73dd8decb2b4a83791ec28f";
		hash = "sha256-cIA0qLwxuBtEyRnWug/pLtm2PaCLWruuvp9HQSwBy0M=";
	};

	installPhase = ''
		mkdir -p $out/share $out/bin
		cp *.py $out/share
		cat <<- EOF > $out/bin/vmwarevmx
			#!/bin/sh
			exec ${python}/bin/python $out/share/main.py "\$@"
		EOF
		chmod a+x $out/bin/vmwarevmx
	'';
}
