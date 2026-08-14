{ config, lib, pkgs, ... }: {

	options.programs.develop.enable = lib.mkEnableOption "developer programs";

	config = let

		smallCodingModel = {
			name = "huihui_ai/qwen3.5-abliterated:9b";
			contextLength = 262144;
			outputLimit = 81920;
		};

	in lib.mkIf config.programs.develop.enable (lib.mkMerge [

		(lib.mkIf pkgs.stdenv.hostPlatform.isLinux {

			security.sandbox.enable = lib.mkDefault true;

			environment.profile = [
				"nixpkgs#git"
				"nixpkgs#swift"
			];
		})

		(lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {

			# Apple developer tools
			programs.xcode.enable = lib.mkDefault true;
			programs.sfSymbols.enable = lib.mkDefault true;

			# OpenCode with local coding model
			programs.opencode.enable = lib.mkDefault true;
			programs.opencode.settings.model = "ollama/${smallCodingModel.name}";
			programs.opencode.settings.small_model = "ollama/${smallCodingModel.name}";
			programs.opencode.settings.provider.ollama.models."${smallCodingModel.name}".limit = {
				context = smallCodingModel.contextLength;
				output = smallCodingModel.outputLimit;
			};
			services.ollama.enable = lib.mkDefault true;
			services.ollama.models = [ smallCodingModel.name ];

			# OpenCode by default is not sandboxed, enable discretionary sandboxing
			security.sandbox.enable = lib.mkDefault true;
			security.sandbox.rules = { ... }: "\${XCODE_SANDBOX_EXTRA_RULES}";

			# auxiliary developer tools
			environment.bundles."/Applications/GitUp.app" = {
				pkg = pkgs.callPackage ../../packages/gitup.nix {};
				install = ''
					makeTree 755::admin "$out" "$pkg$out"
					checkSig "$out" FP44AY6HHW
				'';
			};
			environment.bundles."/Applications/Dash.app" = {
				pkg = pkgs.callPackage ../../packages/dash.nix {};
				install = ''
					makeTree 755::admin "$out" "$pkg$out"
					checkSig "$out" JP58VMK957
				'';
			};
		})
	]);
}
