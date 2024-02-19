{ nixpkgs ? <nixpkgs>, system ? builtins.currentSystem }:
with import nixpkgs { inherit system; };

mkShellNoCC {
	packages = [];
}
