# my custom build of the unison sync tool
{ stdenv, ocaml, xcodeenv, writeText, glibc, patchelf, unison, static ? false }:

if stdenv.isDarwin then (
	# build Unison.app from sources
	# TODO: xcodebuild writes to the home directory, so this only works in a nix develop shell
	let
		xcode = (xcodeenv.composeXcodeWrapper {
				version = "14.2";
			}).overrideAttrs (attrs: {
				buildCommand = attrs.buildCommand + ''
					ln -s /usr/bin/ar $out/bin/
					ln -s /usr/bin/ld $out/bin/
					ln -s clang $out/bin/cc
				'';
			});
		# for building a back-deployable version for macOS
#		ocaml = ocamlPackages.ocaml.overrideAttrs (attrs: {
#			preConfigure = "MACOSX_DEPLOYMENT_TARGET=10.7";
#		});
	in stdenv.mkDerivation rec {
		pname = "unison";
		version = unison.version;
		src = unison.src;
		__noChroot = true;
		nativeBuildInputs = [ ocaml xcode ];
		patches = writeText "unison-fixes.patch" ''
			--- a/src/globals.ml
			+++ b/src/globals.ml
			@@ -101,7 +101,7 @@ let installRoots2 () =
			   let roots = rawRoots () in
			   theroots :=
			     Safelist.map Remote.canonize ((Safelist.map Clroot.parseRoot) roots);
			-  Lwt.ignore_result (Negotiate.features (Common.sortRoots !theroots) >>= return)
			+  Lwt_unix.run (Negotiate.features (Common.sortRoots !theroots))
			 
			 let roots () =
			   match !theroots with
			--- a/src/uimac/uimacnew.xcodeproj/project.pbxproj
			+++ b/src/uimac/uimacnew.xcodeproj/project.pbxproj
			@@ -647,6 +647,7 @@
			 			baseConfigurationReference = 2E282CCC0D9AE2E800439D01 /* ExternalSettings.xcconfig */;
			 			buildSettings = {
			 				ALWAYS_SEARCH_USER_PATHS = NO;
			+				ARCHS = x86_64;
			 				CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED = YES;
			 				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
			 				CLANG_WARN_BOOL_CONVERSION = YES;
			@@ -662,6 +663,7 @@
			 				CLANG_WARN_STRICT_PROTOTYPES = YES;
			 				CLANG_WARN_UNREACHABLE_CODE = YES;
			 				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
			+				CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO;
			 				ENABLE_STRICT_OBJC_MSGSEND = YES;
			 				GCC_NO_COMMON_BLOCKS = YES;
			 				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
			@@ -671,6 +673,7 @@
			 				GCC_WARN_UNUSED_FUNCTION = YES;
			 				GCC_WARN_UNUSED_VARIABLE = YES;
			 				LIBRARY_SEARCH_PATHS = "";
			+				MACOSX_DEPLOYMENT_TARGET = 12.0;
			 				PRODUCT_BUNDLE_IDENTIFIER = edu.upenn.cis.Unison;
			 				SDKROOT = macosx;
			 				SYSTEM_HEADER_SEARCH_PATHS = "$(OCAMLLIBDIR)";
		'';
		preBuild = "unset LD";
		makeFlags = [
			"-C src"
#			"MACOSX_DEPLOYMENT_TARGET=10.7"
#			"UISTYLE=text"
		];
		installPhase = "mv src/uimac/build/Default/Unison.app ./";
		fixupPhase = "echo 'copy Unison.app to /Users/Shared/Library/CoreServices and build the UnisonIntercept project to finalize'";
		meta = unison.meta;
	}
) else (
	# Linux build
	(unison.override {
		enableX11 = false;
		wrapGAppsHook = null;
	}).overrideAttrs (attrs: if static then {
		# optionally build a static binary that can be copied to other systems
		buildInputs = attrs.buildInputs ++ [ glibc.static ];
		makeFlags = attrs.makeFlags ++ [ "LDFLAGS=-static" ];
	} else {
		# otherwise link against system C library for better system consistency
		postFixup = "${patchelf}/bin/patchelf --remove-rpath $out/bin/*";
	})
)
