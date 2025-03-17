# tex wrapper package with useful environment variables and a fonts.conf file
# pass a package set for a custom tex distribution, otherwise defaults apply
{ lib, extend, texPkgs ? {} }:

with extend (final: prev: {
	# modify derivation construction so XeTeX builds with CoreText rendering
	stdenv = prev.stdenv // {
		mkDerivation = arg: if builtins.isAttrs arg then
			prev.stdenv.mkDerivation (arg // (
				if builtins.elem "xetex" (arg.outputs or []) then {
					buildInputs = arg.buildInputs ++ final.lib.optionals prev.stdenv.isDarwin [
						final.darwin.apple_sdk.frameworks.ApplicationServices
						final.darwin.apple_sdk.frameworks.Cocoa
						final.darwin.libobjc
					];
				} else {}
			))
		else prev.stdenv.mkDerivation arg;
	};
});

let tex = texlive.combine (
	if texPkgs != {} then texPkgs else {
		# default tex distribution
		inherit (texlive) scheme-small;
		inherit (texlive) collection-bibtexextra collection-latexextra collection-mathscience;
		inherit (texlive) libertine inconsolata newtx tracklang;
		inherit (texlive) preview;  # for inline preview in LyX
	}
);

in stdenv.mkDerivation ({

	# wrap the TeXLive binaries to add custom environment variables
	name = "texlive-" + (builtins.parseDrvName tex.name).version;
	src = null;
	propagatedUserEnvPkgs = [ tex ];
	phases = "installPhase fixupPhase installCheckPhase";

} // lib.optionalAttrs stdenv.isDarwin rec {

	__noChroot = true;
	fontsConf = makeFontsConf { fontDirectories = [
		"/Library/Fonts"
		"/System/Library/Fonts"
		"~/.local/state/nix/profile/share/texmf/fonts"
	]; };
	installPhase = ''
		mkdir -p $out/etc
		cp ${fontsConf} $out/etc/fonts.conf
		mkdir -p $out/nix-support
		cat <<- EOF > $out/nix-support/wrapper
			#!/bin/bash -e
			export FONTCONFIG_FILE=$out/etc/fonts.conf
			export TEXMFHOME=\$HOME/Library/texmf
			export TEXMFVAR=\''${TMPDIR}/texmf
			export XDG_CACHE_HOME=\''${TMPDIR}
			exec "${tex}/bin/\`basename "\$0"\`" "\$@"
		EOF
		chmod a+x $out/nix-support/wrapper
		mkdir -p $out/bin
		for src in ${tex}/bin/* ; do
			ln -s ../nix-support/wrapper "$out/bin/`basename "$src"`"
		done
		# gs needed for inline preview in LyX, but may have been pulled in already
		test -e $out/bin/gs || ln -s ${ghostscript}/bin/gs $out/bin/
	'';
	doInstallCheck = true;
	installCheckPhase = ''
		cat <<- EOF > test.tex
			\documentclass{article}
			\usepackage{fontspec}
			\setmainfont[
				Renderer=OpenType,
				SmallCapsFont={Hoefler Text/OT:+smcp},
				ItalicFeatures={SmallCapsFont={Hoefler Text/I/OT:+smcp}}]
					{Hoefler Text}
			\begin{document}
			Hamburgefonstiv \par
			{\scshape Hamburgefonstiv} \par
			{\itshape Hamburgefonstiv} \par
			{\scshape \itshape Hamburgefonstiv} \par
			\end{document}
		EOF
		$out/bin/xelatex test.tex
	'';
})
