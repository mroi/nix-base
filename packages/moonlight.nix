# Moonlight game streaming client
{ stdenvNoCC, fetchFromGitHub, fetchzip, fetchpatch, xcodeenv, which, git }:

stdenvNoCC.mkDerivation rec {
	pname = "moonlight";
	version = "1.1.0-unstable-2025-08-24";

	src = fetchFromGitHub {
		owner = "MichaelMKenny";
		repo = "moonlight-macos";
		rev = "d3f2dd3847a0b982fe64b5ffea105b286d7a53cb";
		deepClone = true;
		fetchSubmodules = true;
		hash = "sha256-qSDQv5qK3hfBc+xyWZAcI3cu+mVL9FjnRf1yVHFvGbI=";
	};
	postUnpack = let
		openssl = fetchzip {
			url = "https://github.com/krzyzanowskim/OpenSSL/releases/download/3.3.2000/OpenSSL.xcframework.zip";
			hash = "sha256-m34uj8wJOv5bS8FxyPtkSnLWxRuB9GrsjYtfZMighKA=";
		};
		xcframeworks = fetchzip {
			url = "https://github.com/coofdy/moonlight-mobile-deps/releases/download/latest/moonlight-apple-xcframeworks.zip";
			stripRoot = false;
			hash = "sha256-/360UyB5vWfImps3S2ADLpXoB+7shIqlvmp9aeL2Sew=";
		};
	in ''
		# symlink required frameworks
		ln -s ${openssl} source/xcframeworks/OpenSSL.xcframework
		ln -s ${xcframeworks}/* source/xcframeworks/
	'';

	patches = fetchpatch {
		url = "https://github.com/mroi/moonlight/compare/vendor...main.patch";
		hash = "sha256-g4Z36GT0DuLPJ4ESVs1/+A5eKqqjgV7B0KCIr2P+2TU=";
	};
	postPatch = ''
		# create openssl include directory
		ln -sf ../../xcframeworks/OpenSSL.xcframework/macos-arm64_x86_64/OpenSSL.framework/Headers moonlight-common/include/openssl
	'';

	__noChroot = true;
	nativeBuildInputs = [ (xcodeenv.composeXcodeWrapper {}) which git ];
	buildPhase = ''
		# generate build number from git history
		SRCROOT=. PROJECT_DIR=. source Limelight/build-number.sh

		xcodebuild \
			-scheme 'Moonlight for macOS' \
			-configuration Release \
			-derivedDataPath $NIX_BUILD_TOP/DerivedData \
			OTHER_SWIFT_FLAGS=-disable-sandbox \
			MARKETING_VERSION=${version} \
			build
	'';

	installPhase = ''
		mkdir -p $out/Applications
		cp -R ../DerivedData/Build/Products/Release/Moonlight.app $out/Applications/
	'';
	fixupPhase = ''
		# re-sign to avoid library validation error due to OpenSSL having a different team ID
		codesign --sign - --force --deep --preserve-metadata=entitlements $out/Applications/Moonlight.app
	'';

	passthru.updateScript = "nixUpdate --version branch --version-regex='v-mac-(.*)'";
}
