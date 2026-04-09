{ config, lib, pkgs, ... }: {

	options.programs.vmware.enable = lib.mkEnableOption "VMware Fusion";

	config = let

		vmware-fusion-installer = let
			marketingVersion = "25H2u1";
		in pkgs.requireFile {
			name = "VMware-Fusion-${marketingVersion}-25219963_universal.dmg";
			url = "https://support.broadcom.com/group/ecx/productdownloads?subfamily=VMware%20Fusion&freeDownloads=true";
			# nix hash convert --from base16 --hash-algo sha256 <hash in hex from website>
			hash = "sha256-v+iP4WU+UKr8rz/OXqy0xJHUCuXUOlGZyZHK67BLmNA=";
		} // {
			version = "25.0.1";
			passthru.updateScript = ''
				fusion=$(curl --silent https://techdocs.broadcom.com | grep -F 'data-divisions' | \
					xmllint --recover --xpath 'string(//@data-divisions)' - 2> /dev/null | \
					jq --raw-output '.. | objects | select(.title == "VMware Fusion Pro") | .versions[-1].link')
				toc=$(curl --silent "https://techdocs.broadcom.com$fusion.html" | \
					xmllint --html --xpath 'string(//meta[@name="toc"]/@content)' - 2> /dev/null)
				version=$(curl --silent "https://techdocs.broadcom.com$toc" | \
					jq --raw-output '.[] | select(.title == "Release Notes") | .children[0].title | sub("^VMware Fusion (?<version>.*) Release Notes$"; .version)')
				updateVersion marketingVersion "$version"
				if didUpdate ; then
					updateHash hash ${lib.fakeHash}
					updateVersion version 0
				fi
			'';
		};

	in {

		assertions = [{
			assertion = config.programs.vmware.enable -> pkgs.stdenv.isDarwin;
			message = "VMware Fusion is only available on Darwin";
		}];

		system.build.packages = { inherit vmware-fusion-installer; };

		environment.bundles = lib.mkIf config.programs.vmware.enable {
			"/Applications/VMware Fusion.app" = {
				pkg = vmware-fusion-installer;
				install = ''
					checkSig "$pkg" EG7KH642X6
					trace hdiutil attach -quiet "$pkg"
					trace open -W '/Volumes/VMware Fusion/VMware Fusion.app'
					checkSig "$out" EG7KH642X6
					makeIcon "$out" ${./vmware-icon.cpgz}
					trace hdiutil eject -quiet '/Volumes/VMware Fusion'
				'';
			};
		};

		system.files.known = lib.mkIf config.programs.vmware.enable [
			"/Library/Application Support/VMware"
			"/Library/Application Support/VMware/*"
			"/Library/PrivilegedHelperTools"
			"/private/etc/cups/thnuclnt.convs"
			"/private/etc/cups/thnuclnt.types"
			"/private/etc/paths.d/com.vmware.fusion.public"
			"/private/var/db/vmware"
			"/private/var/db/vmware/*"
			"/private/var/log/vnetlib"
			"/usr/libexec/cups/filter/thnucups"
		];
	};
}
