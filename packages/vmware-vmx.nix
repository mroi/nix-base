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
		rev = "82846af012019ef3a40016c36fe25c174f5407d3";
		hash = "sha256-Fm8nczSuNwkTdr73qJRDawqD+w4ER+VZ/TVnE2EQQrw=";
	};

	patches = fetchpatch {
		url = "https://github.com/RF3/VMwareVMX/pull/18.patch";
		hash = "sha256-EItw6lLwyfI23DLgDXdUsg8t0HDiWrZEYFQPSAZFzrU=";
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
