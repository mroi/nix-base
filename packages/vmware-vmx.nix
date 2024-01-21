# tool to decrypt and encrypt VMware vmx files
{ stdenvNoCC, python3, fetchFromGitHub }:

let
	python = python3.withPackages (pkgs:
		[ pkgs.pycryptodome pkgs.cryptography ]
	);

in stdenvNoCC.mkDerivation {
	name = "vmware-vmx";

	src = fetchFromGitHub {
		owner = "RF3";
		repo = "VMwareVMX";
		# curl https://api.github.com/repos/RF3/VMwareVMX/git/refs/heads/master
		rev = "2cabc5091c610ff175abaea67c078dbd356103c4";
		sha256 = "tXrC0zew9nwDEGrLg2bJLV4VTS3UctXSdxsi18At4y0=";
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
