{ config, lib, pkgs, ... }: {

	options.services.arq = {
		enable = lib.mkEnableOption "Arq backup application";
	};

	config = let

		arq-installer = let
			major = "7";
			url = "https://www.arqbackup.com/download/arqbackup/Arq${major}.pkg";
			releaseNotes = "https://www.arqbackup.com/download/arqbackup/arq${major}_release_notes.html";
		in pkgs.fetchurl {
			inherit url;
			pname = "arq-installer";
			version = "7.35.1";
			hash = "sha256-xkrWH2r3DaxsBBdyu0Wj/qzjJaa9DTZCzEaB/nb2WyY=";
			passthru.updateScript = ''
				version=$(curl --silent ${releaseNotes} | \
					xmllint --html --xpath '/html/body/h1[1]/text()' - 2> /dev/null | \
					sed 's/^[^0-9]*//')
				updateVersion version "$version"
				if didUpdate ; then
					shaExpected=$(curl --silent ${releaseNotes} | \
						xmllint --html --xpath '/html/body/p[2]/text()' - 2> /dev/null | \
						sed 's/^.*= *//')
					curl --silent --output Arq.pkg ${url}
					shaObtained=$(sha256sum Arq.pkg | sed 's/ .*//')
					hash=$(nix hash file Arq.pkg)
					if test "$shaExpected" != "$shaObtained" ; then
						printWarning 'Hash mismatch for downloaded Arq.pkg'
						printInfo "expected: $shaExpected"
						printInfo "obtained: $shaObtained"
						hash=${lib.fakeHash}
					fi
					if ! checkSig Arq.pkg 48ZCSDVL96 ; then
						hash=${lib.fakeHash}
					fi
					updateHash hash "$hash"
					rm Arq.pkg
				fi
			'';
		};

	in {

		assertions = [{
			assertion = ! config.services.arq.enable || pkgs.stdenv.isDarwin;
			message = "Arq is only available on Darwin";
		}];

		system.build.packages = { inherit arq-installer; };

		environment.bundles = lib.mkIf config.services.arq.enable {
			"/Applications/Arq.app" = {
				pkg = arq-installer;
				install = ''
					ln -s "$pkg" Arq.pkg
					trace sudo installer -pkg Arq.pkg -target LocalSystem
					rm Arq.pkg
					checkSig "$out" 48ZCSDVL96
				'';
			};
		};
	};
}
