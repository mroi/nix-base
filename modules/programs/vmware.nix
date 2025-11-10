{ config, lib, pkgs, ... }: {

	options.programs.vmware.enable = lib.mkEnableOption "VMware Fusion";

	config = let

		vmware-fusion-installer = let
			marketingVersion = "25H2";
		in pkgs.requireFile {
			name = "VMware-Fusion-${marketingVersion}-24995814_universal.dmg";
			url = "https://support.broadcom.com/group/ecx/productdownloads?subfamily=VMware%20Fusion&freeDownloads=true";
			# nix hash convert --from base16 --hash-algo sha256 <hash in hex from website>
			hash = "sha256-qZXr1v3tQbPy2ofv/2uGdNZon0yZd3KBDqGlwuvijA4=";
		} // {
			version = "25.0.0";
			passthru.updateScript = ''
				fusion=$(curl --silent https://techdocs.broadcom.com/us/en/vmware-cis/desktop-hypervisors.html | \
					xmllint --html --xpath 'string(//*[text()="VMware Fusion Pro"]/following::a[1]/@href)' - 2> /dev/null)
				relnotes=$(curl --silent "https://techdocs.broadcom.com$fusion" | \
					xmllint --html --xpath 'string(//*[text()="Release Notes"]/following::span[1]/@href)' - 2> /dev/null)
				version=$(curl --silent "https://techdocs.broadcom.com$relnotes" | \
					xmllint --html --xpath 'substring-before(substring-after(//div[text()="Release Notes"]/following::a[1]//text(),"VMware Fusion ")," Release Notes")' - 2> /dev/null)
				updateVersion marketingVersion "$version"
				if didUpdate ; then
					updateHash hash ${lib.fakeHash}
					updateVersion version 0
				fi
			'';
		};

	in {

		assertions = [{
			assertion = ! config.programs.vmware.enable || pkgs.stdenv.isDarwin;
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
	};
}
