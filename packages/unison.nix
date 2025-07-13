# my custom build of the unison sync tool
{ lib, stdenv, stdenvNoCC, ocaml, xcodeenv, fetchFromGitHub, writeText, glibc, patchelf, unison,
	intercept ? false, backDeploy ? false, static ? false }:

assert !intercept || !backDeploy;
assert !intercept || !static;
assert !backDeploy || stdenv.isDarwin;
assert !static || stdenv.isLinux;

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

	# build Unison.app for Darwin
	unisonDarwin = stdenvNoCC.mkDerivation {
		name = unison.name;
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
			export XCODEFLAGS='${lib.concatStringsSep " " [
				"-arch ${stdenv.hostPlatform.darwinArch}"
				"-scheme uimac"
				"-configuration Default"
				"-derivedDataPath $$NIX_BUILD_TOP/DerivedData"
				"MACOSX_DEPLOYMENT_TARGET=$$MACOSX_DEPLOYMENT_TARGET"
			]}'
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
			cp -R src/uimac/build/Default/Unison.app $out/Library/CoreServices/
		'';
		meta = unison.meta;
	};

	# command-line-only Linux build
	unisonLinux = (unison.override {
		enableX11 = false;
		wrapGAppsHook3 = null;
	}).overrideAttrs (attrs:
		if static then {
			# build a static binary that can be copied to other systems
			buildInputs = attrs.buildInputs ++ [ glibc.static ];
			makeFlags = attrs.makeFlags ++ [ "LDFLAGS=-static" ];
		} else {
			# otherwise link against system C library for better system consistency
			postFixup = "${patchelf}/bin/patchelf --remove-rpath $out/bin/*";
		}
	);

	unisonPackage = lib.getAttr stdenv.hostPlatform.uname.system {
		Darwin = unisonDarwin;
		Linux = unisonLinux;
	};

	# Unison with intercept library for additional Unison functionality
	unisonIntercept = stdenvNoCC.mkDerivation {
		name = unison.name;
		version = unison.version;
		src = fetchFromGitHub {
			owner = "mroi";
			repo = "unison-intercept";
			rev = "0bad2ed69c59b68313791be69d890db3c0eea4cf";
			fetchSubmodules = true;
			hash = "sha256-fTRVmZfJgMitq3n2txF3VaZc/3de18nRsOR3M9g1i/U=";
		};
		__noChroot = stdenv.isDarwin;
		nativeBuildInputs = lib.getAttr stdenv.hostPlatform.uname.system {
			Darwin = [ xcode ];
			Linux = [ stdenv.cc ];
		};
		# disable fortify as it causes function wrapping, perturbing intercept linking
		hardeningDisable = [ "fortify" ];
		preBuild = ''
			touch encrypt/.git  # prevent submodule init by Makefile
		'' + lib.optionalString stdenv.isDarwin ''
			mkdir -p $out/Library/CoreServices
			cp -R ${unisonPackage}/Library/CoreServices/Unison.app $out/Library/CoreServices/
			chmod -R u+w $out/Library/CoreServices/Unison.app
			unset DEVELOPER_DIR SDKROOT
			export XCODEFLAGS='${lib.concatStringsSep " " [
				"-arch ${stdenv.hostPlatform.darwinArch}"
				"-scheme Unison"
				"-derivedDataPath $$NIX_BUILD_TOP/DerivedData"
				"UNISON_PATH=$$out/Library/CoreServices/Unison.app"
				"CODE_SIGN_IDENTITY=-"
				"INSTALL_GROUP="
			]}'
		'';
		dontInstall = stdenv.isDarwin;
		installPhase = lib.optionalString stdenv.isLinux ''
			mkdir -p $out/bin $out/lib
			cp ${unisonPackage}/bin/unison $out/bin/
			cp libintercept.so $out/lib/
		'';
		# link against system C library
		postFixup = lib.optionalString stdenv.isLinux ''
			${patchelf}/bin/patchelf --remove-rpath $out/lib/*
		'';
		passthru.updateScript = "nixUpdate --version branch";
	};

in if intercept then unisonIntercept else unisonPackage
