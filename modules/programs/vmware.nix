{ config, lib, pkgs, ... }: {

	options.programs.vmware.enable = lib.mkEnableOption "VMware Fusion";

	config = lib.mkIf config.programs.vmware.enable {

		assertions = [{
			assertion = ! config.programs.vmware.enable || pkgs.stdenv.isDarwin;
			message = "VMware Fusion is only available on Darwin";
		}];

		environment.bundles."/Applications/VMware Fusion.app" = {
			pkg = pkgs.callPackage ../../packages/vmware-fusion.nix {};
			install = ''
				makeTree 755:root:admin "$out" "$pkg$out"
				checkSig "$out" EG7KH642X6
			'';
		};
	};
}
