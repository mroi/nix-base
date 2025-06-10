# cross-compilation package sets and build fixes
# obtain the actual cross compiler from the buildPackages attribute set
{ system ? builtins.currentSystem, nixpkgs ? <nixpkgs> }:

let cross = final: prev: {

	# https://github.com/NixOS/nixpkgs/pull/103517
	glibcCross = prev.glibcCross.overrideAttrs (attrs: {
		preConfigure = attrs.preConfigure + "unset NIX_COREFOUNDATION_RPATH";
	});
};
in {
	linux32 = import nixpkgs { overlays = [ cross ]; system = system; crossSystem = { config = "i686-linux"; }; };
	linux64 = import nixpkgs { overlays = [ cross ]; system = system; crossSystem = { config = "x86_64-linux"; }; };
	linuxarm = import nixpkgs { overlays = [ cross ]; system = system; crossSystem = { config = "aarch64-linux"; }; };
	win32 = import nixpkgs { overlays = [ cross ]; system = system; crossSystem = { config = "i686-w64-mingw32"; libc = "msvcrt"; }; };
	win64 = import nixpkgs { overlays = [ cross ]; system = system; crossSystem = { config = "x86_64-w64-mingw32"; libc = "msvcrt"; }; };
}
