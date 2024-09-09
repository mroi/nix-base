{ config, lib, ... }: {

	options.users.groups = lib.mkOption {
		type = lib.types.attrsOf (lib.types.nullOr
			(lib.types.submodule { options = {
				gid = lib.mkOption {
					type = lib.mkOptionType {
						name = "gid";
						check = gid: lib.isInt gid && gid >= 600;
					};
					description = "The group’s GID.";
				};
				members = lib.mkOption {
					type = lib.types.listOf (lib.types.passwdEntry lib.types.str);
					default = [];
					description = "The user names that are members of this group.";
				};
				description = lib.mkOption {
					type = lib.types.passwdEntry lib.types.str;
					default = "";
					description = "The group’s description.";
				};
			};})
		);
		default = {};
		description = "Configuration for groups. Set a group to `null` for removal.";
	};

	config = let

		groupsToCreate = lib.attrsToList (lib.filterAttrs (n: v: v != null) config.users.groups);
		groupsToDelete = lib.attrsToList (lib.filterAttrs (n: v: v == null) config.users.groups);

		createGroupScript = group: ''
			createGroup <<- EOF
				name=${group.name}
				${lib.toShellVars (group.value // {
					members = lib.concatStringsSep " " group.value.members;
				})}
			EOF
		'';
		deleteGroupScript = group: ''
			deleteGroup '${group.name}'
		'';

	in {

		assertions = [{
			assertion = lib.allUnique (map (group: group.value.gid) groupsToCreate);
			message = "GIDs of the configured groups are not unique.";
		}];

		warnings = lib.pipe config.users.groups [
			lib.attrValues
			(lib.catAttrs "members")
			lib.flatten
			(lib.subtractLists (lib.attrNames config.users.users))
			(map (member: "User ${member} referenced as group member, but not known to exist."))
		];

		system.activationScripts.groups = ''
			storeHeading 'Configuring groups'

			${lib.concatLines (map deleteGroupScript groupsToDelete)}
			${lib.concatLines (map createGroupScript groupsToCreate)}
		'';
	};
}
