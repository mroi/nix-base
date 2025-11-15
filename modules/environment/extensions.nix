{ config, lib, pkgs, ... }: {

	options.environment.extensions = lib.mkOption {
		type = lib.types.attrsOf (lib.types.attrsOf lib.types.bool);
		example = lib.literalExpression "{ \"com.apple.share-services\".\"com.apple.share.AirDrop.send\" = true; }";
		default = {};
		description = "User selection state of extensions, grouped by extension type.";
	};

	config = let

		extensionTypes = lib.attrNames config.environment.extensions;
		extensionTypeScript = type: ''
			current="$(pluginkit --match --protocol ${type} | sed 's/  *// ; s/(.*)$//')"
			${lib.concatLines (map (extensionEnableScript type) (extensionsToEnable type))}
			${lib.concatLines (map (extensionDisableScript type) (extensionsToDisable type))}
		'';

		extensions = lib.flatten (map lib.attrNames (lib.attrValues config.environment.extensions));
		extensionsToEnable = type: lib.attrNames (lib.filterAttrs (_: v: v) config.environment.extensions.${type});
		extensionsToDisable = type: lib.attrNames (lib.filterAttrs (_: v: !v) config.environment.extensions.${type});
		extensionEnableScript = type: extension: ''
			if ! hasLine "$current" +${extension} ; then
				trace pluginkit -e use --protocol ${type} --identifier ${extension}
			fi
		'';
		extensionDisableScript = type: extension: ''
			if ! hasLine "$current" -${extension} ; then
				trace pluginkit -e ignore --protocol ${type} --identifier ${extension}
			fi
		'';

	in {

		assertions = [{
			assertion = config.environment.extensions == {} || pkgs.stdenv.isDarwin;
			message = "Extension selection is only supported on Darwin";
		} {
			assertion = lib.all (type: type == lib.escapeShellArg type) extensionTypes;
			message = "Invalid extension type";
		} {
			assertion = lib.all (ext: ext == lib.escapeShellArg ext) extensions;
			message = "Invalid extension identifier";
		}];

		system.activationScripts.extensions = lib.stringAfter [ "apps" "bundles" ] ''
			storeHeading 'User selection of extensions'
			${lib.concatLines (map extensionTypeScript extensionTypes)}
		'';
	};
}
