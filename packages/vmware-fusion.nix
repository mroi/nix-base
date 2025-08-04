# installer for VMware Fusion
{ lib, stdenvNoCC, requireFile, undmg }:

stdenvNoCC.mkDerivation rec {

	pname = "vmware-fusion";
	version = "13.6.4";

	src = requireFile {
		name = "VMware-Fusion-${version}-24832108_universal.dmg";
		url = "https://support.broadcom.com/group/ecx/productdownloads?subfamily=VMware%20Fusion";
		# nix hash convert --from base16 --hash-algo sha256 <hash in hex from website>
		hash = "sha256-pD/QMRZYlrwbfsxh6wezd7/AGwFMkRGwjhimoa8SEZE=";
	};

	__noChroot = true;
	nativeBuildInputs = [ undmg ];
	sourceRoot = ".";
	installPhase = ''
		mkdir -p $out/Applications
		mv 'VMware Fusion.app' $out/Applications/
		/usr/bin/ditto -xz ${./vmware-icon.cpgz} "$out/Applications/VMware Fusion.app/"
		unset DEVELOPER_DIR  # FIXME: remove when https://github.com/NixOS/nixpkgs/issues/371465 is resolved
		/usr/bin/SetFile -a C "$out/Applications/VMware Fusion.app"
	'';
	dontFixup = true;

	# FIXME
	passthru.updateScript = ''
		fusion=$(curl --silent https://techdocs.broadcom.com/us/en/vmware-cis/desktop-hypervisors.html | \
			xmllint --html --xpath 'string(//*[text()="VMware Fusion Pro"]/following::a[1]/@href)' - 2> /dev/null)
		relnotes=$(curl --silent "https://techdocs.broadcom.com$fusion" | \
			xmllint --html --xpath 'string(//*[text()="Release Notes"]/following::span[1]/@href)' - 2> /dev/null)
		version=$(curl --silent "https://techdocs.broadcom.com$relnotes" | \
			xmllint --html --xpath 'substring-before(substring-after(//div[text()="Release Notes"]/following::a[1]//text(),"VMware Fusion ")," Release Notes")' - 2> /dev/null)
		updateVersion version "$version"
		if didUpdate ; then updateHash hash ${lib.fakeHash} ; fi
	'';
}
