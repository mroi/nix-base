{ config, lib, pkgs, ... }: let

	jsonFormat = pkgs.formats.json {};

	configFile = jsonFormat.generate "opencode.json" ({
		"$schema" = "https://opencode.ai/config.json";
	} // config.programs.opencode.settings);

	# model configuration
	opencodeConfig = {
		provider = lib.mapAttrs opencodeProvider config.services.llms.providers;
	};

	opencodeProvider = let
		openaiCompatible = value: {
			npm = "@ai-sdk/openai-compatible";
			options.baseURL = "${value.url}/v1";
		};
	in _: value: {
		inherit (value) name;
		models = lib.mapAttrs opencodeModel value.models;
	} // lib.getAttr value.type {
		github-copilot = {};
		litellm = openaiCompatible value;
		ollama = openaiCompatible value;
		openai = openaiCompatible value;
	};

	opencodeModel = _: value: {
		inherit (value) name;
		limit.context = value.context;
		limit.output = value.outputLimit;
		options = lib.mkIf (value.thinking != null) {
			reasoning_effort = value.thinking;
		};
	};

	# include MCP servers in the opencode config
	mcpPackage = pkgs.callPackage ../../packages/mcp-servers.nix {};

	mcpServers = {
		mcp = lib.genAttrs mcpPackage.servers (server: {
			type = "local";
			command = [ "mcp-servers" server ];
			enabled = true;
		});
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
		} // opencodeConfig // mcpServers;

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
