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
			version = "7.48";
			hash = "sha256-auz1m6ai10B/6NKTrA/tH6/HqCf9u+aD8kMgB3sZot4=";
			passthru.updateScript = ''
				version=$(curl --silent ${releaseNotes} | \
					xmllint --html --xpath '/html/body/h1[1]/text()' - 2> /dev/null | \
					sed 's/^[^0-9]*//')
				updateVersion version "$version"
				if didUpdate ; then
					shaExpected=$(curl --silent ${releaseNotes} | \
						xmllint --html --xpath '/html/body/p[2]/text()' - 2> /dev/null | \
						sed 's/^.*= *//')
					hashExpected=$(nix hash convert --from base16 --hash-algo sha256 "$shaExpected")
					curl --silent --output Arq.pkg ${url}
					hashObtained=$(nix hash file Arq.pkg)
					if test "$hashExpected" != "$hashObtained" ; then
						printWarning 'Hash mismatch for downloaded Arq.pkg'
						printInfo "expected: $hashExpected"
						printInfo "obtained: $hashObtained"
						hashExpected=${lib.fakeHash}
					fi
					if ! $isDarwin || ! checkSig Arq.pkg 48ZCSDVL96 ; then
						hashExpected=${lib.fakeHash}
					fi
					updateHash hash "$hashExpected"
					rm Arq.pkg
				fi
			'';
		};

	in {

		assertions = [{
			assertion = config.services.arq.enable -> pkgs.stdenv.hostPlatform.isDarwin;
			message = "Arq is only available on Darwin";
		}];

		system.build.packages = { inherit arq-installer; };

		environment.bundles = lib.mkIf config.services.arq.enable {
			"/Applications/Arq.app" = {
				pkg = arq-installer;
				install = ''
					installPackage "$pkg"
					checkSig "$out" 48ZCSDVL96
				'';
			};
		};

		system.files.known = lib.mkIf config.services.arq.enable [
			"/Library/Application Support/ArqAgent"
			"/Library/Application Support/ArqAgent/*"
			"/Library/Application Support/ArqAgentAPFS.noindex"
			"/Library/LaunchDaemons/com.haystacksoftware.arqagent.plist"
		];
		system.files.connections = [
			"(/Library/Application Support/ArqAgent/cache.noindex/backups/2/[^/]*)/.*"
		];
	};
}
