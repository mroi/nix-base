# macos version of fsmonitor tool for unison, which enables the -watch option
{ lib, stdenv, rustPlatform, darwin, fetchFromGitHub }:

rustPlatform.buildRustPackage {
	name = "unison-fsmonitor";
	src = fetchFromGitHub {
		owner = "autozimu";
		repo = "unison-fsmonitor";
		rev = "v0.3.8";
		hash = "sha256-1W05b9s0Pg2LzNu0mFo/JKpPw0QORqZkXhbbSuCZIUo=";
	};

	cargoHash = "sha256-EXAAd2fWdq8kh5mP7WC+SV8ta4Gv8iSZJgUU/EvQD7A=";
	buildInputs = lib.optionals stdenv.isDarwin [
		darwin.apple_sdk.frameworks.CoreServices
	];
	
	checkFlags = [
		# test uses a symlink escaping the nix sandbox
		"--skip=test::test_follow_link"
	];
}
