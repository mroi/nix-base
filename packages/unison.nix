# my custom build of the unison sync tool
{ lib, stdenv, stdenvNoCC, ocaml, xcodeenv, fetchFromGitHub, writeText, glibc, patchelf, unison,
	intercept ? false, static ? false }:

assert intercept -> ! static;
assert static -> stdenv.hostPlatform.isLinux;

let

	xcode = (xcodeenv.composeXcodeWrapper {}).overrideAttrs (attrs: {
		buildCommand = attrs.buildCommand + ''
			ln -s /usr/bin/ar $out/bin/
			ln -s /usr/bin/cc $out/bin/
			ln -s /usr/bin/ld $out/bin/
		'';
	});

	# build Unison.app for Darwin
	unisonDarwin = stdenvNoCC.mkDerivation {
		inherit (unison) name pname version src meta;
		__noChroot = true;
		nativeBuildInputs = [ ocaml xcode ];
		patches = writeText "unison-fixes.patch" ''
			--- a/src/uimac/Makefile
			+++ b/src/uimac/Makefile
			@@ -14,7 +14,7 @@
			 	$(CC) $(CFLAGS) cltool.c -o build/Default/Unison.app/Contents/MacOS/cltool -framework Carbon
			 	codesign --remove-signature build/Default/Unison.app
			 	codesign --force --sign - build/Default/Unison.app/Contents/MacOS/cltool
			-	codesign --force --sign - --entitlements build/uimac*.build/Default/uimac.build/Unison.app.xcent build/Default/Unison.app
			+	codesign --force --sign - --entitlements $(NIX_BUILD_TOP)/DerivedData/Build/Intermediates.noindex/uimac*.build/Default/uimac.build/Unison.app.xcent build/Default/Unison.app
			 	codesign --verify --deep --strict build/Default/Unison.app
			 # cltool was added into the .app after it was signed, so the signature is now
			 # broken. It must be removed, cltool separately signed, and then the entire
			--- a/src/uimac/UnisonToolbar.m
			+++ b/src/uimac/UnisonToolbar.m
			@@ -53,78 +53,91 @@
			     if ([itemIdent isEqual: QuitItemIdentifier]) {
			                 [toolbarItem setLabel: @"Quit"];
			                 [toolbarItem setImage: [NSImage imageNamed: @"quit.tif"]];
			+                [toolbarItem setBordered:NO];
			                 [toolbarItem setTarget:NSApp];
			                 [toolbarItem setAction:@selector(terminate:)];
			         }
			         else if ([itemIdent isEqual: OpenItemIdentifier]) {
			         [toolbarItem setLabel: @"Open"];
			         [toolbarItem setImage: [NSImage imageNamed: @"go.tif"]];
			+        [toolbarItem setBordered:NO];
			         [toolbarItem setTarget:myController];
			         [toolbarItem setAction:@selector(openButton:)];
			     }
			         else if ([itemIdent isEqual: NewItemIdentifier]) {
			         [toolbarItem setLabel: @"New"];
			         [toolbarItem setImage: [NSImage imageNamed: @"add.tif"]];
			+        [toolbarItem setBordered:NO];
			         [toolbarItem setTarget:myController];
			         [toolbarItem setAction:@selector(createButton:)];
			     }
			         else if ([itemIdent isEqual: CancelItemIdentifier]) {
			         [toolbarItem setLabel: @"Cancel"];
			         [toolbarItem setImage: [NSImage imageNamed: @"restart.tif"]];
			+        [toolbarItem setBordered:NO];
			         [toolbarItem setTarget:myController];
			         [toolbarItem setAction:@selector(chooseProfiles)];
			     }
			         else if ([itemIdent isEqual: SaveItemIdentifier]) {
			         [toolbarItem setLabel: @"Save"];
			         [toolbarItem setImage: [NSImage imageNamed: @"save.tif"]];
			+        [toolbarItem setBordered:NO];
			         [toolbarItem setTarget:myController];
			         [toolbarItem setAction:@selector(saveProfileButton:)];
			     }
			         else if ([itemIdent isEqual: GoItemIdentifier]) {
			         [toolbarItem setLabel: @"Go"];
			         [toolbarItem setImage: [NSImage imageNamed: @"go.tif"]];
			+        [toolbarItem setBordered:NO];
			         [toolbarItem setTarget:myController];
			         [toolbarItem setAction:@selector(syncButton:)];
			     }
			     else if ([itemIdent isEqual: RestartItemIdentifier]) {
			         [toolbarItem setLabel: @"Restart"];
			         [toolbarItem setImage: [NSImage imageNamed: @"restart.tif"]];
			+        [toolbarItem setBordered:NO];
			         [toolbarItem setTarget:myController];
			         [toolbarItem setAction:@selector(restartButton:)];
			     }
			     else if ([itemIdent isEqual: RescanItemIdentifier]) {
			         [toolbarItem setLabel: @"Rescan"];
			         [toolbarItem setImage: [NSImage imageNamed: @"rescan.tif"]];
			+        [toolbarItem setBordered:NO];
			         [toolbarItem setTarget:myController];
			         [toolbarItem setAction:@selector(rescan:)];
			     }
			     else if ([itemIdent isEqual: RToLItemIdentifier]) {
			         [toolbarItem setLabel: @"Right to left"];
			         [toolbarItem setImage: [NSImage imageNamed: @"left.tif"]];
			+        [toolbarItem setBordered:NO];
			         [toolbarItem setTarget:tableView];
			         [toolbarItem setAction:@selector(copyRL:)];
			     }
			     else if ([itemIdent isEqual: MergeItemIdentifier]) {
			         [toolbarItem setLabel: @"Merge"];
			         [toolbarItem setImage: [NSImage imageNamed: @"merge.tif"]];
			+        [toolbarItem setBordered:NO];
			         [toolbarItem setTarget:tableView];
			         [toolbarItem setAction:@selector(merge:)];
			     }
			         else if ([itemIdent isEqual: LToRItemIdentifier]) {
			         [toolbarItem setLabel: @"Left to right"];
			         [toolbarItem setImage: [NSImage imageNamed: @"right.tif"]];
			+        [toolbarItem setBordered:NO];
			         [toolbarItem setTarget:tableView];
			         [toolbarItem setAction:@selector(copyLR:)];
			         }
			         else if ([itemIdent isEqual: SkipItemIdentifier]) {
			         [toolbarItem setLabel: @"Skip"];
			         [toolbarItem setImage: [NSImage imageNamed: @"skip.tif"]];
			+        [toolbarItem setBordered:NO];
			         [toolbarItem setTarget:tableView];
			         [toolbarItem setAction:@selector(leaveAlone:)];
			         }
			         else if ([itemIdent isEqual: DiffItemIdentifier]) {
			         [toolbarItem setLabel: @"Diff"];
			         [toolbarItem setImage: [NSImage imageNamed: @"diff.tif"]];
			+        [toolbarItem setBordered:NO];
			         [toolbarItem setTarget:tableView];
			         [toolbarItem setAction:@selector(showDiff:)];
			         }
		'';
		postPatch = ''
			cp ${./unison.icns} src/uimac/Unison.icns
		'';
		preBuild = ''
			unset LD
			unset DEVELOPER_DIR SDKROOT
			export MACOSX_DEPLOYMENT_TARGET=14.0
			export XCODEFLAGS='${lib.concatStringsSep " " [
				"-arch ${stdenv.hostPlatform.darwinArch}"
				"-scheme uimac"
				"-configuration Default"
				"-derivedDataPath $$NIX_BUILD_TOP/DerivedData"
				"MACOSX_DEPLOYMENT_TARGET=$$MACOSX_DEPLOYMENT_TARGET"
			]}'
		'';
		makeFlags = [
			"-C src"
		];
		installPhase = ''
			mkdir -p $out/Library/CoreServices
			cp -R src/uimac/build/Default/Unison.app $out/Library/CoreServices/
		'';
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
		inherit (unison) name pname version;
		src = fetchFromGitHub {
			owner = "mroi";
			repo = "unison-intercept";
			rev = "082ece6680834e565c2010d27bfa7a2d87bb3a5e";
			fetchSubmodules = true;
			hash = "sha256-En9mYe1IvV+dzYbVRMFh/GzA2l7uR+HGS5/RFWilNcg=";
		};
		__noChroot = stdenv.hostPlatform.isDarwin;
		nativeBuildInputs = lib.getAttr stdenv.hostPlatform.uname.system {
			Darwin = [ xcode ];
			Linux = [ stdenv.cc ];
		};
		# disable fortify as it causes function wrapping, perturbing intercept linking
		hardeningDisable = [ "fortify" ];
		preBuild = ''
			touch encrypt/.git  # prevent submodule init by Makefile
		'' + lib.optionalString stdenv.hostPlatform.isDarwin ''
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
		dontInstall = stdenv.hostPlatform.isDarwin;
		installPhase = lib.optionalString stdenv.hostPlatform.isLinux ''
			mkdir -p $out/bin $out/lib
			cp ${unisonPackage}/bin/unison $out/bin/
			cp libintercept.so $out/lib/
		'';
		# link against system C library
		postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
			${patchelf}/bin/patchelf --remove-rpath $out/lib/*
		'';
		passthru.updateScript = "nixUpdate --version branch";
	};

in if intercept then unisonIntercept else unisonPackage
