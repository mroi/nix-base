# tool to convert Outlook MSG files to EML
{ stdenvNoCC, python3, fetchurl, fetchFromGitHub }:

# we want to use the nixpkgs version if these become officially available
assert ! python3.pkgs ? compoundfiles;
assert ! python3.pkgs ? rtfparse;

let
	compoundfiles = python3.pkgs.buildPythonPackage {
		pname = "compoundfiles";
		version = "0.3";
		src = fetchurl {
			url = "https://files.pythonhosted.org/packages/78/c8/46e0bcf2b4158f501b57ea928350487bf1062459c9d8a226dfda8986c40c/compoundfiles-0.3.tar.gz";
			hash = "sha256-pDXBBTeGhQp4t0ubpqMXqrKul0QtSPPsU5LcLFHBYek=";
		};
		format = "setuptools";
		doCheck = false;
	};

	rtfparse = python3.pkgs.buildPythonPackage {
		pname = "rtfparse";
		version = "0.9.5";
		src = fetchurl {
			url = "https://files.pythonhosted.org/packages/fc/6a/1a718df5f4479f5dcf5cf3be017808b492e2aa65587685d7d35b58ae5094/rtfparse-0.9.5-py3-none-any.whl";
			hash = "sha256-5oPlYuV66Q4lnCn83q3JZEcmcGoPJOUGdWzd+yPzLmk";
		};
		format = "wheel";
		doCheck = false;
		propagatedBuildInputs = with python3.pkgs; [ argcomplete compressed-rtf extract-msg ];
	};

	python = python3.withPackages (pkgs: [
		compoundfiles rtfparse pkgs.compressed-rtf pkgs.html2text
	]);

in stdenvNoCC.mkDerivation {
	pname = "outlookmsg";
	version = "0-unstable-2025-11-14";

	src = fetchFromGitHub {
		owner = "JoshData";
		repo = "convert-outlook-msg-file";
		rev = "24bf2968c8e4758580887af896c1f37da804a0e2";
		hash = "sha256-WZdfG/Ict694DngFCsCkRnIbA2TBXqP2aXoqfz10iBE=";
	};

	installPhase = ''
		mkdir -p $out/share $out/bin
		cp *.py $out/share
		cat <<- EOF > $out/bin/outlookmsg
			#!/bin/sh
			exec ${python}/bin/python $out/share/outlookmsgfile.py < "\$1"
		EOF
		chmod a+x $out/bin/outlookmsg
	'';

	passthru.updateScript = "nixUpdate --version branch";
}
