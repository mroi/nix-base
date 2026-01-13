{ config, lib, pkgs, ... }: {

	options.networking.interfaces = lib.mkOption {
		type = lib.types.attrsOf (lib.types.submodule { options = {
			ipv4.addresses = lib.mkOption {
				type = lib.types.listOf (lib.types.submodule { options = {
					address = lib.mkOption {
						type = lib.types.str;
						description = "Statically configured IPv4 address of the interface.";
					};
					prefixLength = lib.mkOption {
						type = lib.types.ints.between 0 32;
						description = "Subnet mask of the interface, specified as the number of bits in the prefix.";
					};
				};});
				default = [];
				example = [{ address = "192.168.1.1"; prefixLength = 24; }];
				description = "List of statically configured IPv4 addresses of the interface.";
			};
		};});
		default = {};
		description = "Configuration of individual network interfaces.";
	};

	config = let

		subnetMask = lib.elemAt [
			"0.0.0.0"
			"128.0.0.0"
			"192.0.0.0"
			"224.0.0.0"
			"240.0.0.0"
			"248.0.0.0"
			"252.0.0.0"
			"254.0.0.0"
			"255.0.0.0"
			"255.128.0.0"
			"255.192.0.0"
			"255.224.0.0"
			"255.240.0.0"
			"255.248.0.0"
			"255.252.0.0"
			"255.254.0.0"
			"255.255.0.0"
			"255.255.128.0"
			"255.255.192.0"
			"255.255.224.0"
			"255.255.240.0"
			"255.255.248.0"
			"255.255.252.0"
			"255.255.254.0"
			"255.255.255.0"
			"255.255.255.128"
			"255.255.255.192"
			"255.255.255.224"
			"255.255.255.240"
			"255.255.255.248"
			"255.255.255.252"
			"255.255.255.254"
			"255.255.255.255"
		];

		interfaceScript = { name, value }: let
			ipv4 = lib.head value.ipv4.addresses;
		in ''
			config="$(networksetup -getinfo ${name} 2>&1 || true)"
		'' + lib.optionalString (value ? ipv4.addresses) ''
			if ! hasLine "$config" 'Manual Configuration' ||
				! hasLine "$config" 'IP address: ${ipv4.address}' ||
				! hasLine "$config" 'Subnet mask: ${subnetMask ipv4.prefixLength}' ||
				! hasLine "$config" 'Router: (null)'; then
				trace sudo networksetup -setmanual ${name} ${ipv4.address} ${subnetMask ipv4.prefixLength} ""
			fi
		'';

		checkAll = pred: lib.all pred (lib.attrValues config.networking.interfaces);

	in {

		assertions = [{
			assertion = config.networking.interfaces != {} -> pkgs.stdenv.isDarwin;
			message = "Network interface currently can only be configured on Darwin";
		} {
			assertion = checkAll (x: x ? ipv4.addresses -> lib.tail x.ipv4.addresses == []);
			messages = "Network interfaces require exactly one IPv4 address configuration";
		}];

		system.activationScripts.interfaces = ''
			storeHeading 'Configuring network interfaces'

			${lib.concatLines (map interfaceScript (lib.attrsToList config.networking.interfaces))}
		'';
	};
}
