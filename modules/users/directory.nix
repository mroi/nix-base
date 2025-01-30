{ config, lib, pkgs, ... }: {

	options.users.directory = {

		information.searchPolicy = lib.mkOption {
			type = lib.types.enum [ "local" "automatic" "custom" ];
			default = "local";
			description = "Search policy by which directory services are queried when user details are requested.";
		};
		authentication.searchPolicy = lib.mkOption {
			type = lib.types.enum [ "local" "automatic" "custom" ];
			default = "local";
			description = "Search policy by which directory services are queried when user authentication is requested.";
		};
	};

	config = lib.mkIf (pkgs.stdenv.isDarwin && config.system.systemwideSetup) {

		system.activationScripts.directory = let

			toPolicyString = x: lib.getAttr x {
				local = "LSPSearchPath";
				automatic = "NSPSearchPath";
				custom = "CSPSearchPath";
			};

		in ''
			storeHeading 'Configuring directory services'

			# user information search policy
			value=$(dscl /Search/Contacts -read / SearchPolicy)
			target=${toPolicyString config.users.directory.information.searchPolicy}
			if test "''${value%"$target"}" = "$value" ; then
				trace sudo dscl /Search/Contacts -create / SearchPolicy "dsAttrTypeStandard:$target"
			fi

			# authentication search policy
			value=$(dscl /Search -read / SearchPolicy)
			target=${toPolicyString config.users.directory.authentication.searchPolicy}
			if test "''${value%"$target"}" = "$value" ; then
				trace sudo dscl /Search -create / SearchPolicy "dsAttrTypeStandard:$target"
			fi
		'';
	};
}
