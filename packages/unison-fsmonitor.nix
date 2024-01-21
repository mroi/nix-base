# macos version of fsmonitor tool for unison, which enables the -watch option
{ lib, stdenv, rustPlatform, darwin, fetchFromGitHub }:

rustPlatform.buildRustPackage {
	name = "unison-fsmonitor";
	src = fetchFromGitHub {
		owner = "autozimu";
		repo = "unison-fsmonitor";
		rev = "v0.3.3";
		hash = "sha256-JA0WcHHDNuQOal/Zy3yDb+O3acZN3rVX1hh0rOtRR+8=";
	};
	cargoHash = "sha256-iqq66JLmAMCXnvtiN9yf0dY/AGzlo+wAqj9ZM3UYIP0=";
	buildInputs = lib.optionals stdenv.isDarwin [
		darwin.apple_sdk.frameworks.CoreServices
	];
}
