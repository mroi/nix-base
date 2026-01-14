{ config, lib, pkgs, ... }: {

	options.fileSystems = lib.mkOption {
		type = lib.types.attrsOf (lib.types.nullOr
			(lib.types.submodule { options = {
				autoVolume = lib.mkEnableOption "automatic volume creation" // {
					default = true;
				};
				container = lib.mkOption {
					type = lib.types.nullOr lib.types.path;
					default = "/";
					description = "Create this volume within the container hosting another volume.";
				};
				encrypted = lib.mkEnableOption "volume encryption";
				fsType = lib.mkOption {
					type = lib.types.nonEmptyStr;
					default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
						Linux = "ext4";
						Darwin = "APFS";
					};
					description = "The file system type.";
				};
				ownership = lib.mkEnableOption "file ownership information";
				hidden = lib.mkEnableOption "volume hidden state";
			};})
		);
		default = {};
		description = "The file systems to be mounted. The attribute name designates the mount point.";
	};

	config = let

		volumesToCreate = lib.attrsToList (lib.filterAttrs (n: v: v != null) config.fileSystems);
		volumesToDelete = lib.attrsToList (lib.filterAttrs (n: v: v == null) config.fileSystems);

		volumeProperties = volume: (if volume.value != null then volume.value else {}) // {
			name = lib.pipe volume.name [
				builtins.baseNameOf
				# capitalize first letter
				(x: "${lib.toUpper (lib.substring 0 1 x)}${lib.substring 1 (-1) x}")
			];
			mountPoint = volume.name;
			keyStorage = "${config.users.root.stagingDirectory}/login-hook.sh";
			keyVariable = "${lib.toUpper (builtins.baseNameOf volume.name)}_VOLUME_PASSWORD";
		};

		createVolumeScript = volume: lib.optionalString volume.value.autoVolume ''
			makeVolume <<- EOF
				${lib.toShellVars (volumeProperties volume)}
			EOF
		'';
		deleteVolumeScript = volume: with volumeProperties volume; ''
			deleteVolume '${name}'
		'';
		mountVolumeScript = volume: with volumeProperties volume; let
			script = if lib.hasPrefix "/Volumes" mountPoint then {
				mountTest = "! test -d ${lib.escapeShellArg mountPoint}";
				mountPoint = "";
			} else {
				mountTest = "test \"$(stat -f %d /)\" = \"$(stat -f %d ${lib.escapeShellArg mountPoint})\"";
				mountPoint = " -mountpoint ${lib.escapeShellArg mountPoint}";
			};
		in ''
			# mount ${name} volume
			if ${script.mountTest} ; then
				${if encrypted then (
					"${keyVariable}= # placeholder, will be filled at runtime\n\t\t\t\t" +
					"echo \"\$${keyVariable}\" | diskutil quiet apfs unlock ${lib.escapeShellArg name} -stdinpassphrase${script.mountPoint}"
				) else
					"diskutil quiet apfs unlock ${lib.escapeShellArg name}${script.mountPoint}"
				}
			fi'';

	in {

		assertions = [{
			assertion = config.fileSystems != {} -> pkgs.stdenv.isDarwin;
			message = "Volume creation is currently only supported on Darwin";
		}];

		system.activationScripts.volumes = lib.mkIf (config.fileSystems != {}) (lib.stringAfter [ "staging" ]''
			storeHeading 'Creating volumes and file systems'

			${lib.concatLines (map deleteVolumeScript volumesToDelete)}
			${lib.concatLines (map createVolumeScript volumesToCreate)}
		'');

		environment.loginHook = lib.mkIf (config.fileSystems != {}) {
			volumes = lib.optionalString pkgs.stdenv.isDarwin (
				lib.concatLines (map mountVolumeScript (lib.filter (x: x.name != "/") volumesToCreate))
			);
		};
		system.activationScripts.hooks = lib.mkIf (config.fileSystems != {}) {
			deps = [ "volumes" ];
		};

		system.cleanupScripts.volumes = lib.optionalString pkgs.stdenv.isDarwin ''
			storeHeading 'Checking volume and file system integrity'

			{
				trace diskutil verifyDisk disk0
				container=$(diskutil info -plist / | plutil -extract ParentWholeDisk raw -)
				trace diskutil verifyVolume "$container"
			} | highlightOutput '
				/^Checking volume/{s/^/%UNDERLINE%/;s/$/%NOUNDERLINE%/;}
				/^warning:/{s/^/%YELLOW%/;s/$/%NORMAL%/;}
				/^Skipped .* repairs/{s/^/%RED%/;s/$/%NORMAL%/;}
				/needs to be repaired$/{s/^/%RED%/;s/$/%NORMAL%/;}
				/appears to be OK$/{s/^/%GREEN%/;s/$/%NORMAL%/;}
			'
		'';
	};
}
