# my custom build of the unison sync tool
{ lib, stdenv, ocaml, xcodeenv, writeText, glibc, patchelf, unison, backDeploy ? false, static ? false }:

if stdenv.isDarwin then (

	# build Unison.app from sources
	let
		xcode = (xcodeenv.composeXcodeWrapper {
				versions = [ "14.2" ];
			}).overrideAttrs (attrs: {
				buildCommand = attrs.buildCommand + ''
					ln -s /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild $out/bin/
					ln -s /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ar $out/bin/
					ln -s /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ld $out/bin/
					rm $out/bin/clang
				'';
			});
		# for building a back-deployable version for macOS
		ocaml' = ocaml.overrideAttrs (attrs:
			if backDeploy then {
				preConfigure = "MACOSX_DEPLOYMENT_TARGET=10.7";
			} else {}
		);

	in stdenv.mkDerivation rec {
		pname = "unison";
		version = unison.version;
		src = unison.src;
		__noChroot = true;
		nativeBuildInputs = [ ocaml' xcode ];
		patches = writeText "unison-fixes.patch" ''
			--- a/src/Makefile.OCaml
			+++ b/src/Makefile.OCaml
			@@ -231,7 +231,7 @@
			 	$(CC) $(CFLAGS) $(UIMACDIR)/cltool.c -o $(UIMACDIR)/build/Default/Unison.app/Contents/MacOS/cltool -framework Carbon
			 	codesign --remove-signature $(UIMACDIR)/build/Default/Unison.app
			 	codesign --force --sign - $(UIMACDIR)/build/Default/Unison.app/Contents/MacOS/cltool
			-	codesign --force --sign - --entitlements $(UIMACDIR)/build/uimac*.build/Default/uimac.build/Unison.app.xcent $(UIMACDIR)/build/Default/Unison.app
			+	codesign --force --sign - --entitlements $(NIX_BUILD_TOP)/DerivedData/Build/Intermediates.noindex/uimac*.build/Default/uimac.build/Unison.app.xcent $(UIMACDIR)/build/Default/Unison.app
			 	codesign --verify --deep --strict $(UIMACDIR)/build/Default/Unison.app
			 # cltool was added into the .app after it was signed, so the signature is now
			 # broken. It must be removed, cltool separately signed, and then the entire
		'';
		preBuild = ''
			unset LD
			export XCODEFLAGS="-arch x86_64 -scheme uimac -configuration Default -derivedDataPath $NIX_BUILD_TOP/DerivedData"
		'';
		makeFlags = [
			"-C src"
		] ++ lib.optionals (!backDeploy) [
			"MACOSX_DEPLOYMENT_TARGET=12.0"
		] ++ lib.optionals backDeploy [
			"MACOSX_DEPLOYMENT_TARGET=10.7"
			"UISTYLE=text"
		];
		installPhase = ''
			mkdir -p $out/Library/CoreServices
			cp -r src/uimac/build/Default/Unison.app $out/Library/CoreServices/
		'';
		meta = unison.meta;
	}

) else (

	# Linux build
	(unison.override {
		enableX11 = false;
		wrapGAppsHook3 = null;
	}).overrideAttrs (attrs:
		if static then {
			# optionally build a static binary that can be copied to other systems
			buildInputs = attrs.buildInputs ++ [ glibc.static ];
			makeFlags = attrs.makeFlags ++ [ "LDFLAGS=-static" ];
		} else {
			# otherwise link against system C library for better system consistency
			postFixup = "${patchelf}/bin/patchelf --remove-rpath $out/bin/*";
		}
	)
)
