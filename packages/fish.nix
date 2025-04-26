# custom derivation to reduce trust in Nixpkgs for my standard shell by enforcing oversight
# in addition, use XDG_STATE_DIR for fish state files and generated completions
{ lib, path, stdenv, rustPlatform,
	cargo, cmake, coreutils, darwin, fetchFromGitHub, fishPlugins, gawk, getent, gettext,
	glibcLocales, gnugrep, gnused, groff, libiconv, man-db, ncurses, ninja, nixosTests,
	nix-update-script, pcre2, pkg-config, procps, python3, runCommand, rustc, sphinx,
	versionCheckHook, writableTmpDirAsHomeHook, writeText
}:

let
	fish = import "${path}/pkgs/by-name/fi/fish/package.nix" {
		# will cause errors if derivation inputs change
		inherit cargo cmake coreutils darwin fishPlugins gawk getent gettext
			glibcLocales gnugrep gnused groff lib libiconv man-db ncurses ninja nixosTests
			nix-update-script pcre2 pkg-config procps python3 runCommand rustc sphinx
			versionCheckHook writableTmpDirAsHomeHook writeText;
		# passthrough functions for argument inspection
		stdenv = stdenv // { mkDerivation = x: lib.fix x; };
		fetchFromGitHub = x: (fetchFromGitHub x) // x;
		rustPlatform = rustPlatform // { fetchCargoVendor = x: (rustPlatform.fetchCargoVendor x) // x; };
	};
	expect = { expected, actual, error }:
		if actual == expected then actual else throw ("fish " + error + " " + toString actual);

in stdenv.mkDerivation {
	pname = fish.pname;
	version = fish.version;
	src = fetchFromGitHub {
		owner = expect {
			expected = "fish-shell";
			actual = fish.src.owner;
			error = "source owner changed:";
		};
		repo = expect {
			expected = "fish-shell";
			actual = fish.src.repo;
			error = "source repo changed:";
		};
		tag = fish.version;
		hash = expect {
			expected = "sha256-UpoZPipXZbzLWCOXzDjfyTDrsKyXGbh3Rkwj5IeWeY4=";
			actual = fish.src.hash;
			error = ("source sha256 changed, please run and compare:\n" +
				"curl -L https://github.com/${fish.src.owner}/${fish.src.repo}/archive/refs/tags/${fish.src.tag}.tar.gz | tar x ; nix hash path ${fish.src.repo}-${fish.src.tag} ; rm -rf ${fish.src.repo}-${fish.src.tag} ; echo");
		};
	};
	cargoDeps = rustPlatform.fetchCargoVendor {
		inherit (fish) src;
		hash = expect {
			expected = "sha256-FkJB33vVVz7Kh23kfmjQDn61X2VkKLG9mUt8f3TrCHg=";
			actual = fish.cargoDeps.hash;
			error = "cargo deps hash changed:";
		};
	};
	outputs = expect {
		expected = [ "out" "doc" ];
		actual = fish.outputs;
		error = "outputs changed:";
	};

	nativeBuildInputs = expect {
		expected = [ cargo cmake gettext ninja pkg-config rustc rustPlatform.cargoSetupHook writableTmpDirAsHomeHook ];
		actual = fish.nativeBuildInputs;
		error = "nativeBuildInputs changed:";
	};
	buildInputs = expect {
		expected = [ libiconv pcre2 ];
		actual = fish.buildInputs;
		error = "buildInputs changed:";
	};
	propagatedBuildInputs = expect {
		expected = [ coreutils gnugrep gnused groff gettext ] ++ lib.optional (!stdenv.isDarwin) man-db;
		actual = fish.propagatedBuildInputs;
		error = "propagatedBuildInputs changed:";
	};

	patches = [(writeText "fish-fix-xdg.patch" ''
		--- fish-shell/src/path.rs	2025-03-18 21:23:26
		+++ fish-shell/src/path.rs	2025-03-18 21:24:22
		@@ -94,7 +94,7 @@
		             L!("data"),
		             wgettext!("can not save history"),
		             data.used_xdg,
		-            L!("XDG_DATA_HOME"),
		+            L!("XDG_STATE_HOME"),
		             &data.path,
		             data.err,
		             vars,
		@@ -769,13 +769,13 @@
		 
		 fn get_data_directory() -> &'static BaseDirectory {
		     static DIR: Lazy<BaseDirectory> =
		-        Lazy::new(|| make_base_directory(L!("XDG_DATA_HOME"), L!("/.local/share/fish")));
		+        Lazy::new(|| make_base_directory(L!("XDG_STATE_HOME"), L!("/.local/state/fish")));
		     &DIR
		 }
		 
		 fn get_cache_directory() -> &'static BaseDirectory {
		     static DIR: Lazy<BaseDirectory> =
		-        Lazy::new(|| make_base_directory(L!("XDG_CACHE_HOME"), L!("/.cache/fish")));
		+        Lazy::new(|| make_base_directory(L!("XDG_STATE_HOME"), L!("/.local/state/fish")));
		     &DIR
		 }
		 
		--- fish-shell/share/tools/create_manpage_completions.py	2025-03-18 22:35:42
		+++ fish-shell/share/tools/create_manpage_completions.py	2025-03-18 22:37:10
		@@ -1136,11 +1136,11 @@
		         sys.exit(0)
		 
		     if not args.stdout and not args.directory:
		-        # Default to ~/.cache/fish/generated_completions
		+        # Default to ~/.local/state/fish/generated_completions
		         # Create it if it doesn't exist
		-        xdg_cache_home = os.getenv("XDG_CACHE_HOME", "~/.cache")
		+        xdg_state_home = os.getenv("XDG_STATE_HOME", "~/.local/state")
		         args.directory = os.path.expanduser(
		-            xdg_cache_home + "/fish/generated_completions/"
		+            xdg_state_home + "/fish/generated_completions/"
		         )
		         try:
		             os.makedirs(args.directory)
	'')];

	preConfigure = expect {
		expected = "patchShebangs ./build_tools/git_version_gen.sh\npatchShebangs ./tests/test_driver.py\n";
		actual = fish.preConfigure;
		error = "preConfigure changed:";
	};
	cmakeFlags = expect {
		expected = [
			"-DCMAKE_INSTALL_DOCDIR:STRING=${placeholder "doc"}/share/doc/fish"
			"-DRust_CARGO_TARGET:STRING=${stdenv.hostPlatform.rust.rustcTarget}"
		] ++ lib.optionals stdenv.isDarwin [ "-DMAC_CODESIGN_ID:BOOL=FALSE" ];
		actual = fish.cmakeFlags;
		error = "cmakeFlags changed:";
	};
	env = { FISH_BUILD_VERSION = fish.version; };

	meta = fish.meta;
}
