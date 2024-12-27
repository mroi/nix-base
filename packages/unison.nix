# my custom build of the unison sync tool
{ lib, stdenv, stdenvNoCC, ocaml, xcodeenv, writeText, glibc, patchelf, unison, backDeploy ? false, static ? false }:

if stdenv.isDarwin then (

	# build Unison.app from sources
	let
		xcode = (xcodeenv.composeXcodeWrapper {}).overrideAttrs (attrs: {
			buildCommand = attrs.buildCommand + ''
				ln -s /usr/bin/ar $out/bin/
				ln -s /usr/bin/cc $out/bin/
				ln -s /usr/bin/ld $out/bin/
			'';
		});
		# for building a back-deployable version for macOS
		ocaml' = ocaml.overrideAttrs (attrs:
			if backDeploy then {
				preConfigure = "MACOSX_DEPLOYMENT_TARGET=10.7";
			} else {}
		);

	in stdenvNoCC.mkDerivation rec {
		pname = "unison";
		version = unison.version;
		src = unison.src;
		__noChroot = true;
		nativeBuildInputs = [ ocaml' xcode ];
		patches = writeText "unison-fixes.patch" ''
			--- a/src/Makefile.OCaml
			+++ b/src/Makefile.OCaml
			@@ -316,7 +316,7 @@
			 	$(CC) $(CFLAGS) $(UIMACDIR)/cltool.c -o $(UIMACDIR)/build/Default/Unison.app/Contents/MacOS/cltool -framework Carbon
			 	codesign --remove-signature $(UIMACDIR)/build/Default/Unison.app
			 	codesign --force --sign - $(UIMACDIR)/build/Default/Unison.app/Contents/MacOS/cltool
			-	codesign --force --sign - --entitlements $(UIMACDIR)/build/uimac*.build/Default/uimac.build/Unison.app.xcent $(UIMACDIR)/build/Default/Unison.app
			+	codesign --force --sign - --entitlements $(NIX_BUILD_TOP)/DerivedData/Build/Intermediates.noindex/uimac*.build/Default/uimac.build/Unison.app.xcent $(UIMACDIR)/build/Default/Unison.app
			 	codesign --verify --deep --strict $(UIMACDIR)/build/Default/Unison.app
			 # cltool was added into the .app after it was signed, so the signature is now
			 # broken. It must be removed, cltool separately signed, and then the entire
		'';
		postPatch = ''
			cp ${./unison.icns} src/uimac/Unison.icns
		'';
		preBuild = ''
			unset LD
			unset DEVELOPER_DIR SDKROOT
			export XCODEFLAGS='-arch ${stdenv.hostPlatform.darwinArch} -scheme uimac -configuration Default -derivedDataPath $$NIX_BUILD_TOP/DerivedData MACOSX_DEPLOYMENT_TARGET=$$MACOSX_DEPLOYMENT_TARGET'
		'' + lib.optionalString (!backDeploy) ''
			export MACOSX_DEPLOYMENT_TARGET=14.0
		'' + lib.optionalString backDeploy ''
			export MACOSX_DEPLOYMENT_TARGET=10.7
		'';
		makeFlags = [
			"-C src"
		] ++ lib.optionals backDeploy [
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
