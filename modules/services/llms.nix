{ config, lib, pkgs, ... }: {

	options.services.llms = {
		providers = lib.mkOption {
			type = lib.types.attrsOf (lib.types.submodule { options = {
				name = lib.mkOption {
					type = lib.types.str;
					description = "A user-readable name for this provider.";
				};
				aliases = lib.mkOption {
					type = lib.types.listOf lib.types.str;
					default = [];
					description = "Shorthand aliases for this provider.";
				};
				type = lib.mkOption {
					type = lib.types.enum [ "github-copilot" "litellm" "ollama" "openai" ];
					description = "Provider service type.";
				};
				url = lib.mkOption {
					type = lib.types.str;
					description = "The URL endpoint for this service";
				};
				models = lib.mkOption {
					type = lib.types.attrsOf (lib.types.submodule { options = {
						name = lib.mkOption {
							type = lib.types.str;
							description = "A user-readable name for this model.";
						};
						tags = lib.mkOption {
							type = lib.types.listOf lib.types.str;
							default = [];
							description = "User-defined tags for this model.";
						};
						context = lib.mkOption {
							type = lib.types.int;
							description = "The context window length of this model.";
						};
						outputLimit = lib.mkOption {
							type = lib.types.int;
							description = "The output token limit for this model.";
						};
						thinking = lib.mkOption {
							type = lib.types.nullOr lib.types.str;
							default = null;
							description = "The thinking effort setting for this model.";
						};
					};});
					default = {};
					description = "Model settings keyed by their internal model name.";
				};
			};});
			default = {};
			description = "An abstract set of LLM providers and favorite models that sits between model providers (to whose configuration it lowers) and client applications (who query this set).";
		};
		enableFishIntegration = lib.mkOption {
			type = lib.types.bool;
			default = lib.any (lib.hasSuffix "#fish") config.environment.profile;
			description = "Generate a fish function to query configured models, for example in fish command wrappers when invoking AI tools.";
		};
	};

	config = let

		# add pseudo-providers derived from the model tags
		providersByTags = lib.concatMapAttrs (name: value: lib.mergeAttrsList ([{
			${name} = value // { inherit name; };
		}] ++ lib.forEach (lib.concatAttrValues (lib.mapAttrs (_: x: x.tags) value.models)) (tag: {
			"${name}-${tag}" = value // {
				inherit name;
				aliases = map (x: "${x}-${tag}") value.aliases;
				models = lib.filterAttrs (_: x: lib.elem tag x.tags) value.models;
			};
		}))) config.services.llms.providers;

		# fish function to query configured models
		fishFile = pkgs.writeText "nix-llms.fish" (lib.concatLines (lib.flatten ([
			"function __nix_llms --description 'query configured LLMs'"
			"	switch $argv[1]"
			"		case ''"
			"			echo '${lib.concatStringsSep " " (lib.attrNames providersByTags)}'"
		] ++ map fishProvider (lib.attrsToList providersByTags) ++ [
			"		case '*'; return 1"
			"	end"
			"end"
		])));

		fishProvider = { name, value }: [
			"		case '${name}'${lib.concatStringsSep " " ([""] ++ value.aliases)}"
			"			switch $argv[2]"
			"				case ''; echo ${value.name}"
			"				case type; echo ${value.type}"
			"				case url; echo ${value.url}"
			"				case model"
			"					switch $argv[3]"
			"						case ''"
			"							echo '${lib.concatStringsSep " " (lib.attrNames value.models)}'"
			"						case 1 2 3 4 5 6 7 8 9"
			"							set res (string split --field $argv[3] ' ' (__nix_llms $argv[1] $argv[2]))"
			"							test -n \"$res\" ; and echo $res"
		] ++ map fishModel (lib.attrsToList value.models) ++ [
			"						case '*'; return 1"
			"					end"
			"				case '*'; return 1"
			"			end"
		];

		fishModel = { name, value }: [
			"						case '${name}'"
			"							switch $argv[4]"
			"								case ''; echo ${name}"
			"								case context; echo ${toString value.context}"
			"								case outputLimit; echo ${toString value.outputLimit}"
		] ++ lib.optionals (value.thinking != null) [
			"								case thinking; echo ${value.thinking}"
		] ++ [
			"								case '*'; return 1"
			"							end"
		];

		# derive Ollama configuration
		ollamaModels = lib.pipe config.services.llms.providers [
			lib.attrValues
			(lib.filter (x: x.type == "ollama"))
			(lib.filter (x: x.url == "http://localhost:11434"))
			(lib.catAttrs "models")
			(map lib.attrNames)
			lib.flatten
		];

	in lib.mkIf (config.services.llms.providers != {}) {

		assertions = [{
			assertion = lib.pipe config.services.llms.providers [
				lib.attrValues
				(map (x: lib.attrValues x.models))
				lib.flatten
				(lib.all (x: x.outputLimit < x.context))
			];
			message = "Configured output limits must be smaller than the context length";
		}];

		services.ollama.enable = lib.mkDefault (ollamaModels != []);
		services.ollama.models = ollamaModels;

		system.activationScripts.llms = ''
			storeHeading 'LLM providers and models'
		'' + lib.optionalString config.services.llms.enableFishIntegration ''
			makeFile 644 "''${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/nix-llms.fish" ${fishFile}
		'';
	};
}
