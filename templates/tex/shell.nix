{ nixpkgs ? <nixpkgs>, system ? builtins.currentSystem }:
with import nixpkgs { inherit system; };

let tex = texliveSmall.withPackages (pkgs: with pkgs; [
	collection-latexextra
	libertine inconsolata newtx
	latexmk
]);
in mkShellNoCC {
	packages = [ tex ];
}
