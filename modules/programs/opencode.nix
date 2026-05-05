{ config, lib, pkgs, ... }: let

	jsonFormat = pkgs.formats.json {};

	configFile = jsonFormat.generate "opencode.json" ({
		"$schema" = "https://opencode.ai/config.json";
	} // config.programs.opencode.settings);

	# model substrings that will be included in opencode config
	codingModels = [ "gemma" "qwen" ];

	prettyModelName = name: lib.pipe name [
		lib.toLower
		# separate into user "/" name version specifier ":" size
		(lib.match "([^/]*/)?([^0-9-]+)(-[^0-9]*)?([0-9.]+)([^:]*):([^-]*)(-.*)?")
		# put together pretty name
		(x: "${lib.elemAt x 1} ${lib.elemAt x 3}" + lib.optionalString ((lib.elemAt x 5) != "latest") " ${lib.elemAt x 5}")
		# capitalize first letter
		(x: "${lib.toUpper (lib.substring 0 1 x)}${lib.substring 1 (-1) x}")
	];

	ollamaProvider = lib.optionalAttrs (config.services.ollama.models != []) {
		provider = {
			ollama = {
				npm = "@ai-sdk/openai-compatible";
				name = "Ollama";
				options.baseURL = "http://localhost:11434/v1";
				models = lib.pipe config.services.ollama.models [
					(lib.filter (x: lib.any (y: lib.hasInfix y (lib.toLower x)) codingModels))
					(map (x: { name = "${x}"; value = {
						name = prettyModelName x;
						reasoning = true;
						tools = true;
					};}))
					lib.listToAttrs
				];
			};
		};
	};

in {

	options.programs.opencode = {
		enable = lib.mkEnableOption "OpenCode";
		settings = lib.mkOption {
			type = jsonFormat.type;
			example = lib.literalExpression ''{ theme = "system"; }'';
			description = "Configuration options for OpenCode.";
		};
	};

	config = lib.mkIf config.programs.opencode.enable {

		environment.profile = [ "nix-base#opencode" ];

		programs.opencode.settings = {
			autoupdate = false;
			default_agent = "plan";
		} // ollamaProvider;

		system.activationScripts.opencode = lib.mkIf (config.programs.opencode.settings != {}) (
			lib.stringAfter [ "shared" ] (''
				storeHeading 'OpenCode configuration'
			'' + lib.optionalString (config.users.shared.folder != null) ''
				makeFile 644::${config.users.shared.group} '${config.users.shared.folder}/.local/config/opencode/config.json' ${configFile}
				makeLink "''${XDG_CONFIG_HOME:-$HOME/.config}/opencode/config.json" '${config.users.shared.folder}/.local/config/opencode/config.json'
			'' + lib.optionalString (config.users.shared.folder == null) ''
				makeFile 644 "''${XDG_CONFIG_HOME:-$HOME/.config}/opencode/config.json" ${configFile}
			'')
		);
	};
}
