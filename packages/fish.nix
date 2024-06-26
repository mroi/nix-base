# custom derivation to reduce trust in Nixpkgs for my standard shell by enforcing oversight
# in addition, use ~/.fish for configuration instead of the XDG directories
{ lib, path, stdenv, fetchurl,
  cmake, coreutils, fetchpatch, fishPlugins, gawk, getent, gettext, gnugrep,
  gnused, groff, libiconv, man-db, ncurses, nixosTests, nix-update-script,
  pcre2, procps, python3, runCommand, which, writeText
}:

let
	fish = import "${path}/pkgs/shells/fish" {
		# will cause errors if derivation inputs change
		inherit cmake coreutils fetchpatch fishPlugins gawk getent gettext gnugrep
			gnused groff lib libiconv man-db ncurses nixosTests nix-update-script
			pcre2 procps python3 runCommand which writeText;
		# passthrough functions for argument inspection
		stdenv = stdenv // { mkDerivation = x: x; };
		fetchurl = x: x;
	};
	expect = { expected, actual, error }:
		if actual == expected then actual else throw ("fish " + error + " " + toString actual);
in stdenv.mkDerivation {
	pname = fish.pname;
	version = fish.version;
	src = fetchurl {
		url = expect {
			expected = "https://github.com/fish-shell/fish-shell/releases/download/${fish.version}/${fish.pname}-${fish.version}.tar.xz";
			actual = fish.src.url;
			error = "source URL changed:";
		};
		hash = expect {
			expected = "sha256-YUyfVkPNB5nfOROV+mu8NklCe7g5cizjsRTTu8GjslA=";
			actual = fish.src.hash;
			error = ("source sha256 changed, please run and compare:\n" +
				"/usr/bin/python3 -c 'import urllib.request,hashlib,base64,string;print(\"sha256-\"+base64.b64encode(hashlib.sha256(urllib.request.urlopen(\"" + fish.src.url + "\").read()).digest()).decode())' ; echo");
		};
	};
	outputs = expect {
		expected = [ "out" "doc" ];
		actual = fish.outputs;
		error = "outputs changed:";
	};

	nativeBuildInputs = expect {
		expected = [ cmake gettext ];
		actual = fish.nativeBuildInputs;
		error = "nativeBuildInputs changed:";
	};
	buildInputs = expect {
		expected = [ ncurses libiconv pcre2 ];
		actual = fish.buildInputs;
		error = "buildInputs changed:";
	};
	propagatedBuildInputs = expect {
		expected = [ coreutils gnugrep gnused groff gettext ] ++ lib.optional (!stdenv.isDarwin) man-db;
		actual = fish.propagatedBuildInputs;
		error = "propagatedBuildInputs changed:";
	};

	patches = [(writeText "fish-fix-xdg.patch" ''
		--- fish-shell/src/path.cpp	2020-02-12 15:04:07.000000000 +0100
		+++ fish-shell/src/path.cpp	2024-02-16 15:09:11.000000000 +0100
		@@ -351,7 +351,7 @@
		 }
		 
		 static const base_directory_t &get_data_directory() {
		-    static base_directory_t s_dir = make_base_directory(L"XDG_DATA_HOME", L"/.local/share/fish");
		+    static base_directory_t s_dir = make_base_directory(L"XDG_STATE_HOME", L"/.local/state/fish");
		     return s_dir;
		 }
		 
	'')];
	preConfigure = expect {
		expected = "patchShebangs ./build_tools/git_version_gen.sh\n";
		actual = fish.preConfigure;
		error = "preConfigure changed:";
	};
	cmakeFlags = expect {
		expected = [ "-DCMAKE_INSTALL_DOCDIR=${placeholder "doc"}/share/doc/fish" ]
			++ lib.optionals stdenv.isDarwin [ "-DMAC_CODESIGN_ID=OFF" ];
		actual = fish.cmakeFlags;
		error = "cmakeFlags changed:";
	};
	postInstall = ''
		sed -i "s|\.config/fish|.local/config/fish|g" \
			"$out/share/fish/functions/__fish_config_interactive.fish" \
			"$out/share/fish/functions/fish_update_completions.fish"
		sed -i "s|\.local/share|.local/state|g" \
			"$out/share/fish/tools/create_manpage_completions.py"
	'';

	meta = fish.meta;
	passthru = fish.passthru;
}
