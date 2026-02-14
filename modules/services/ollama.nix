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

		users = {
			users._ollama = {
				uid = 601;
				group = "_ollama";
				home = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
					Linux = "/var/lib/ollama";
					Darwin = "/private/var/db/ollama";
				};
				description = "Ollama AI Server";
			};
			groups._ollama = {
				gid = 601;
				description = "Ollama AI Server";
			};
		};

		environment.services.ollama-serve = {
			label = "com.ollama.ollama-serve";
			description = "Ollama AI Server";
			command = "${config.users.users._ollama.home}/bin/ollama serve --launchd";
			environment = [ "OLLAMA_MODELS=${config.users.users._ollama.home}" ];
			user = "_ollama";
			lifecycle = "demand";
			socket = "tcp4://localhost:11434";
			socketName = "ollama";
		};

		environment.profile = [ "nix-base#ollama" ];

		system.activationScripts.ollama = let

			ollama = lib.getExe (pkgs.callPackage ../../packages/ollama.nix {});
			datadir = config.users.users._ollama.home;

		in lib.stringAfter [ "users" "services" ] (''
			storeHeading 'Loading and removing Ollama models'

			makeDir 755:_ollama:_ollama ${datadir} ${datadir}/bin
			makeLink 755:_ollama:_ollama ${datadir}/bin/ollama ${ollama}
		'' + lib.optionalString pkgs.stdenv.isDarwin ''
			if ! xattr -p com.apple.metadata:com_apple_backup_excludeItem ${datadir} > /dev/null 2> /dev/null ; then
				trace sudo tmutil addexclusion ${datadir}
			fi
		'' + ''

			target='${lib.concatLines config.services.ollama.models}'
			current="$(cd ${datadir}/manifests/registry.ollama.ai/library 2> /dev/null || exit 0 ; ls -d -- *)"

			# beautify ollama invocations: do not show store path
			ollama() { ${ollama} "$@" ; }

			# install missing models
			forTarget() {
				if ! hasLine "$current" "$1" ; then
					trace ollama pull "$1"
				fi
			}
			forLines "$target" forTarget

			# remove unneeded models
			forCurrent() {
				if ! hasLine "$target" "$1" ; then
					trace ollama rm "$1"
				fi
			}
			forLines "$current" forCurrent
		'');
	};
}
