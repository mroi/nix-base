{ config, lib, pkgs, ... }: {

	options.users = {
		accounts = lib.mkOption {
			type = lib.types.listOf (lib.types.either
				lib.types.str
				(lib.types.submodule { options = {
					name = lib.mkOption {
						type = lib.types.str;
						description = "The user account name.";
					};
					isAdmin = lib.mkEnableOption "administrator access";
				};})
			);
			default = [];
			description = "The list of regular and administrative user accounts.";
		};
		mkAccountName = lib.mkOption {
			type = lib.types.raw;
			default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = name: lib.toLower (lib.head (lib.splitString " " name));
				Darwin = name: lib.head (lib.splitString " " name);
			};
			description = "Function to turn a full name into a user account name.";
		};
	};

	config = let

		mkAccountName = account: config.users.mkAccountName account.name;
		accounts = map (elem: if lib.isString elem then
			{ name = elem; isAdmin = false; } else elem) config.users.accounts;
		indexOf = elem: lib.lists.findFirstIndex (x: x == elem) null accounts;
		concatAccounts = f: lib.mergeAttrsList (map f accounts);
		adminAccounts = lib.filter (x: x.isAdmin) accounts;

	in {

		assertions = [{
			assertion = lib.allUnique (lib.catAttrs "name" accounts);
			message = "Account names of user accounts are not unique";
		}];

		users.users = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
			Linux = concatAccounts (account: {
				"${mkAccountName account}" = {
					uid = 1000 + (indexOf account);
					group = mkAccountName account;
					isHidden = false;
					home = "/home/${mkAccountName account}";
					shell = "/bin/bash";
					description = account.name;
				};
			});
			Darwin = concatAccounts (account: {
				"${mkAccountName account}" = {
					uid = 501 + (indexOf account);
					group = "staff";
					isHidden = false;
					home = "/Users/${mkAccountName account}";
					shell = "/bin/zsh";
					description = account.name;
				};
			});
		};

		users.groups = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
			Linux = concatAccounts (account: {
				"${mkAccountName account}".gid = 1000 + (indexOf account);
			}) // {
				adm.members = map mkAccountName adminAccounts;
				sudo.members = map mkAccountName adminAccounts;
			};
			Darwin = {
				admin.members = map mkAccountName adminAccounts;
			};
		};

		services.timeMachine.excludePaths = lib.mkIf pkgs.stdenv.isDarwin (map
			(account: "/Users/${mkAccountName account}/Downloads")
		accounts);
	};
}
