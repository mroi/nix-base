{ config, lib, pkgs, ... }: {

	options.users.users = lib.mkOption {
		type = lib.types.attrsOf (lib.types.nullOr
			(lib.types.submodule { options = {
				uid = lib.mkOption {
					type = lib.types.int;
					description = "The user’s UID.";
				};
				group = lib.mkOption {
					type = lib.types.passwdEntry lib.types.str;
					description = "The user’s primary group.";
				};
				isHidden = lib.mkOption {
					type = lib.types.bool;
					default = true;
					description = "Whether the user account is hidden.";
				};
				home = lib.mkOption {
					type = lib.types.passwdEntry lib.types.path;
					default = if pkgs.stdenv.isDarwin then "/var/empty" else "/nonexistent";
					description = "The user’s home directory.";
				};
				shell = lib.mkOption {
					type = lib.types.either lib.types.shellPackage (lib.types.passwdEntry lib.types.path);
					default = if pkgs.stdenv.isDarwin then "/usr/bin/false" else "/usr/sbin/nologin";
					description = "The user’s login shell.";
				};
				description = lib.mkOption {
					type = lib.types.str;
					default = "";
					description = "A description of the user account, like a user’s full name.";
				};
			};})
		);
		default = {};
		description = "Configuration for users. Set a user to `null` for removal.";
	};

	config = let

		usersToCreate = lib.attrsToList (lib.filterAttrs (n: v: v != null) config.users.users);
		usersToDelete = lib.attrsToList (lib.filterAttrs (n: v: v == null) config.users.users);

		createUserScript = user: ''
			makeUser <<- EOF
				name=${user.name}
				gid=${toString config.users.groups.${user.value.group}.gid or ""}
				${lib.toShellVars user.value}
			EOF
		'';
		deleteUserScript = user: ''
			deleteUser '${user.name}'
		'';

	in {

		assertions = [{
			assertion = lib.allUnique (map (user: user.value.uid) usersToCreate);
			message = "UIDs of the configured users are not unique";
		}];

		system.activationScripts.users = lib.stringAfter [ "groups" ] ''
			storeHeading 'Configuring users'

			${lib.concatLines (map deleteUserScript usersToDelete)}
			${lib.concatLines (map createUserScript usersToCreate)}
		'';

		system.files.known = lib.pipe config.users.users [
			# add all files under user home directories as known
			lib.attrValues
			(map (x: x.home))
			(lib.filter (x: x != "/var/empty" && x != "/nonexistent"))
			(map (x: if pkgs.stdenv.isDarwin && lib.hasPrefix "/var/" x then "/private${x}" else x))
			(lib.concatMap (x: [ x (x + "/*") ]))
			lib.unique
		];
	};
}
