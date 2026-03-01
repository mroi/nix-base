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
		postFetch = ''
			# extract build number (see Limelight/build-number.sh)
			echo "BUILD_NUMBER = $(git -C $out rev-list --count HEAD)" > $out/Limelight/Version.xcconfig
			rm -rf $out/.git
		'';
		hash = "sha256-KJHKmYnc3d+BFxVxrvuLOTpznP+nqzasbOVFY/jFPYQ=";
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
		# prevent build number extracted during fetchgit from being overwritten
		test "$(md5sum - < Limelight/build-number.sh)" = 'a8c6b152264ed7a7fc0d0410815ae43a  -'
		truncate --size=0 Limelight/build-number.sh

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
