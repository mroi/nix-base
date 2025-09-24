{ config, lib, pkgs, ... }: {

	options.services.ollama = {
		enable = lib.mkEnableOption "Ollama local LLM server";
		models = lib.mkOption {
			type = lib.types.listOf lib.types.str;
			example = [ "devstral" ];
			description = "Models to install within Ollama.";
		};
	};

	config = lib.mkIf config.services.ollama.enable {

		environment.profile = [ "nix-base#ollama" ];

		system.activationScripts.ollama = let
			ollama = lib.getExe (pkgs.callPackage ../../packages/ollama.nix {});
		in ''
			storeHeading 'Loading and removing Ollama models'

			target='${lib.concatLines config.services.ollama.models}'
			current="$(cd "$HOME/.local/state/ollama/manifests/registry.ollama.ai/library" 2> /dev/null || exit 0 ; ls -d -- *)"
			running=

			runServer() {
				if test -z "$running" ; then
					running=$(if pgrep -q ollama ; then echo true ; else echo false ; fi)
				fi
				if ! $running ; then ${ollama} serve > /dev/null 2>&1 & fi
			}
			killServer() {
				if test -z "$running" ; then return ; fi
				if ! $running ; then pkill ollama ; fi
			}

			# install missing models
			forTarget() {
				if ! hasLine "$current" "$1" ; then
					runServer
					trace ${ollama} pull "$1"
				fi
			}
			forLines "$target" forTarget

			# remove unneeded models
			forCurrent() {
				if ! hasLine "$target" "$1" ; then
					runServer
					trace ${ollama} rm "$1"
				fi
			}
			forLines "$current" forCurrent

			killServer
		'';
	};
}
