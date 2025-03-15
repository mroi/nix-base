{ config, lib, pkgs, ... }: {

	options.environment.services = lib.mkOption {
		type = lib.types.attrsOf (lib.types.nullOr
			(lib.types.submodule { options = {
				label = lib.mkOption {
					type = lib.types.singleLineStr;
					description = "Launchd-style reverse DNS name for the service.";
				};
				description = lib.mkOption {
					type = lib.types.singleLineStr;
					description = "Description line for the service.";
				};
				dependencies = lib.mkOption {
					type = lib.types.listOf lib.types.singleLineStr;
					default = [];
					description = "Other services or service targets this service depends upon.";
				};
				oneshot = lib.mkEnableOption "run-to-completion behavior";
				command = lib.mkOption {
					type = lib.types.nonEmptyStr;
					description = "Command to start the service.";
				};
				environment = lib.mkOption {
					type = lib.types.listOf (lib.types.strMatching "[[:alnum:]_]{1,}=.*");
					default = [];
					description = "Environment variables in the form `<variable>=<value>`.";
				};
				group = lib.mkOption {
					type = lib.types.nullOr (lib.types.passwdEntry lib.types.str);
					default = null;
					description = "The service will run within this group.";
				};
				socket = lib.mkOption {
					type = lib.types.nullOr lib.types.path;
					default = null;
					description = "Demand-launch the service when this socket is accessed.";
				};
				waitForPath = lib.mkOption {
					type = lib.types.nullOr lib.types.path;
					default = null;
					description = "Starting the service will be delayed until this path is available.";
				};
			};})
		);
		default = {};
		description = "A service description that gets instantiated as a platform-specfic systemd unit or launchd daemon.";
	};

	config = let

		servicesToCreate = lib.attrsToList (lib.filterAttrs (n: v: v != null) config.environment.services);
		servicesToDelete = lib.attrsToList (lib.filterAttrs (n: v: v == null) config.environment.services);

		createServiceScript = service: ''
			makeService <<- EOF
				name=${service.name}
				${lib.toShellVars (service.value // {
					dependencies = lib.concatStringsSep " " service.value.dependencies;
					environment = lib.concatLines service.value.environment;
				})}
			EOF
		'';
		deleteServiceScript = service: ''
			deleteService '${service.name}'
		'';

	in {

		assertions = (map (service: {
			assertion = lib.hasSuffix service.name service.value.label;
			message = "The last component of label ${service.value.label} must match the service name ${service.name}.";
		}) servicesToCreate)
		++ lib.optionals pkgs.stdenv.isDarwin (map (service: {
			assertion = service.value.socket == null;
			message = "Socket-activated services are currently not implemented on Darwin";
		}) servicesToCreate);

		warnings = lib.pipe config.environment.services [
			lib.attrValues
			(lib.catAttrs "group")
			(lib.filter (group: group != null))
			(lib.subtractLists (lib.attrNames config.users.groups))
			(lib.subtractLists [ "" ])
			(map (group: "Group ${group} referenced by a service is not known to exist."))
		];

		system.activationScripts.services = lib.stringAfter [ "users" "groups" ] ''
			storeHeading 'Installing system services'

			${lib.concatLines (map createServiceScript servicesToCreate)}
			${lib.concatLines (map deleteServiceScript servicesToDelete)}
		'';
	};
}
