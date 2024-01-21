{ nixpkgs ? <nixpkgs>, system ? builtins.currentSystem }:
with import nixpkgs { inherit system; };

let tex = texlive.combine {
	inherit (texlive) scheme-small collection-latexextra;
	inherit (texlive) libertine inconsolata newtx;
	inherit (texlive) latexmk;
};
in mkShellNoCC {
	packages = [ tex ];
	shellHook = "test -r ~/.shellrc && . ~/.shellrc";
}
