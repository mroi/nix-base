# custom derivation to reduce trust in Nixpkgs for my standard shell by enforcing oversight
# in addition, use ~/.fish for configuration instead of the XDG directories
{ lib, path, stdenv, rustPlatform,
	applyPatches, cargo, cmake, coreutils, darwin, fetchFromGitHub, fetchpatch2,
	fishPlugins, gawk, getent, gettext, glibcLocales, gnugrep, gnused, groff, libiconv,
	man-db, ncurses, ninja, nixosTests, nix-update-script, pcre2, pkg-config, procps,
	python3, runCommand, rustc, sphinx, versionCheckHook, writableTmpDirAsHomeHook,
	writeText
}:

let
	fish = import "${path}/pkgs/by-name/fi/fish/package.nix" {
		# will cause errors if derivation inputs change
		inherit applyPatches cargo cmake coreutils darwin fetchFromGitHub fetchpatch2
			fishPlugins gawk getent gettext glibcLocales gnugrep gnused groff lib libiconv
			man-db ncurses ninja nixosTests nix-update-script pcre2 pkg-config procps
			python3 runCommand rustc sphinx versionCheckHook writableTmpDirAsHomeHook
			writeText;
		# passthrough functions for argument inspection
		stdenv = stdenv // { mkDerivation = x: lib.fix x; };
		rustPlatform = rustPlatform // { fetchCargoVendor = x: (rustPlatform.fetchCargoVendor x) // x; };
	};
	expect = { expected, actual, error }:
		if actual == expected then actual else throw ("fish " + error + " " + toString actual);

in stdenv.mkDerivation {
	pname = fish.pname;
	version = fish.version;
	# workaround as long as the applyPatch construction in fish.src is necessary
	src = if
		fish.src.outPath == "/nix/store/sy1mv8cs999c866w5mbxq0lbkgy4w2j2-source-patched" ||
		fish.src.outPath == "/nix/store/abw00by8ci3g7ahrnjvw7ibryglg4hfh-source-patched"
	then fish.src else fetchFromGitHub {
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
			expected = "sha256-BLbL5Tj3FQQCOeX5TWXMaxCpvdzZtKe5dDQi66uU/BM=";
			actual = fish.src.hash;
			error = ("source sha256 changed, please run and compare:\n" +
				"/usr/bin/python3 -c 'import urllib.request,hashlib,base64,string;print(\"sha256-\"+base64.b64encode(hashlib.sha256(urllib.request.urlopen(\"https://github.com/${fish.src.owner}/${fish.src.repo}/archive/refs/tags/${fish.src.tag}.tar.gz\").read()).digest()).decode())' ; echo");
		};
	};
	cargoDeps = rustPlatform.fetchCargoVendor {
		inherit (fish) src;
		hash = expect {
			expected = "sha256-4ol4LvabhtjiMMWwV1wrcywFePOmU0Jub1sy+Ay7mLA=";
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
		--- fish-shell/src/path.rs	1970-01-01 01:00:01
		+++ fish-shell/src/path.rs	2025-03-12 17:17:36
		@@ -94,7 +94,7 @@
		             L!("data"),
		             wgettext!("can not save history"),
		             data.used_xdg,
		-            L!("XDG_DATA_HOME"),
		+            L!("XDG_STATE_HOME"),
		             &data.path,
		             data.err,
		             vars,
		@@ -769,7 +769,7 @@
		 
		 fn get_data_directory() -> &'static BaseDirectory {
		     static DIR: Lazy<BaseDirectory> =
		-        Lazy::new(|| make_base_directory(L!("XDG_DATA_HOME"), L!("/.local/share/fish")));
		+        Lazy::new(|| make_base_directory(L!("XDG_STATE_HOME"), L!("/.local/state/fish")));
		     &DIR
		 }
		 
	'')];

	preConfigure = expect {
		expected = "patchShebangs ./build_tools/git_version_gen.sh\npatchShebangs ./tests/test_driver.py\n";
		actual = fish.preConfigure;
		error = "preConfigure changed:";
	};
	cmakeFlags = expect {
		expected = [ "-DCMAKE_INSTALL_DOCDIR=${placeholder "doc"}/share/doc/fish" ]
			++ lib.optionals stdenv.isDarwin [ "-DMAC_CODESIGN_ID=OFF" ];
		actual = fish.cmakeFlags;
		error = "cmakeFlags changed:";
	};
	env = { FISH_BUILD_VERSION = fish.version; };

	meta = fish.meta;
}
