{ config, lib, pkgs, ... }: {

	# this sandbox should implement the following security policy:
	# * no credentials or other sensitive files can be read from the sandbox
	# * no data can be exfiltrated by writing to locations readable by other users
	# * data exfiltration to the internet is out of scope (currently not restricted)

	options.security.sandbox = {
		enable = lib.mkEnableOption "developer sandbox command";
		init = lib.mkOption {
			type = lib.types.lines;
			default = "";
			description = "Shell code to execute at the beginning of the sandbox script.";
		};
		rules = lib.mkOption {
			type = lib.types.functionTo lib.types.lines;
			default = _: "";
			example = lib.literalExpression "{ ro, rw }: ''\${ro \"HOME\" \"/.vimrc\"}''";
			description = "A function to specify additional sandbox rules.";
		};
	};

	config = {

		# bit of a hack: add internally generated sandbox package to Nix profile
		environment.profile = lib.mkIf config.security.sandbox.enable [
			"nix-base#baseConfigurations.\${_machine}.config.system.build.packages.sandbox"
		];

		system.build.packages.sandbox = let

			# shell expressions for path prefixes
			prefixVars = {
				ROOT = "";
				HOME = "$HOME";
				XDG_BIN_HOME = "\${XDG_BIN_HOME:-$HOME/.local/bin}";
				XDG_CONFIG_HOME = "\${XDG_CONFIG_HOME:-$HOME/.config}";
				XDG_STATE_HOME = "\${XDG_STATE_HOME:-$HOME/.local/state}";
			};

			# functions to generate script for read-only or read-write access to a directory
			ro = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = var: dir: "--ro-bind \"${lib.getAttr var prefixVars}${dir}\" \"${lib.getAttr var prefixVars}${dir}\"";
				Darwin = var: dir: "(allow file-read* file-test-existence (subpath (string-append (param \"${var}\") \"${dir}\")))";
			};
			rw = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = var: dir: "--bind \"${lib.getAttr var prefixVars}${dir}\" \"${lib.getAttr var prefixVars}${dir}\"";
				Darwin = var: dir: "(allow file* (subpath (string-append (param \"${var}\") \"${dir}\")))";
			};

			# escape the sandbox rules so they fit the script and allow shell expansions
			escapeRules = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = lib.replaceString "\n" " \\\n";  # add terminating \ to concatenate command line arguments
				Darwin = x: "\"" + lib.replaceString "\"" "\\\"" x + "\"";  # escape all double quotes plus add outer quotes
			};

			isInstalled = name: lib.any (lib.hasSuffix "#${name}") config.environment.profile;

			# make selected user files available inside the sandbox
			commonSandboxRules = ''
				${ro "XDG_BIN_HOME" ""}
				${ro "XDG_CONFIG_HOME" "/git/config"}
				${ro "XDG_CONFIG_HOME" "/shell"}
			'' + lib.optionalString (isInstalled "fish") ''
				${ro "XDG_CONFIG_HOME" "/fish"}
				${rw "XDG_STATE_HOME" "/fish"}
			'' + lib.optionalString (isInstalled "micro") ''
				${ro "XDG_CONFIG_HOME" "/micro"}
				${rw "XDG_CONFIG_HOME" "/micro/backups"}
				${rw "XDG_CONFIG_HOME" "/micro/buffers"}
			'' + lib.optionalString (isInstalled "opencode") ''
				${ro "XDG_CONFIG_HOME" "/opencode"}
				${rw "XDG_STATE_HOME" "/opencode"}
			'' + lib.optionalString (config.environment.profile != []) ''
				${ro "XDG_STATE_HOME" "/nix"}
			'' + config.security.sandbox.rules { inherit ro rw; };

			# wrap dev tools whose behavior collides with the sandbox
			wrappers = pkgs.runCommand "sandbox-wrappers" {} ''
				mkdir -p $out/bin
				# swift needs --disable-sandbox
				cat <<- 'EOF' > $out/bin/swift
					#!/bin/sh
					if test "$#" -eq 0 -o "$1" != "''${1#-}" ; then
						# invocation without subcommand
						exec /usr/bin/swift "$@"
					else
						# invocation with subcommand
						subcommand=$1 ; shift
						exec /usr/bin/swift "$subcommand" --disable-sandbox "$@"
					fi
				EOF
				cat <<- 'EOF' > $out/bin/xcodebuild
					#!/bin/sh
					if test "''${*#*-scheme }" != "$*" ; then
						# explicit scheme option given
						SWIFTPM_DISABLE_SANDBOX=1 exec /usr/bin/xcodebuild \
							-derivedDataPath "$TMPDIR/xcodebuild-$PPID" \
							ENABLE_USER_SCRIPT_SANDBOXING=NO \
							OTHER_SWIFT_FLAGS=--disable-sandbox \
							"$@"
					else
						# use first available scheme
						scheme=$(ls *.xcodeproj/xcshareddata/xcschemes/*.xcscheme | head -n1)
						scheme=$(basename "$scheme" .xcscheme)
						SWIFTPM_DISABLE_SANDBOX=1 exec /usr/bin/xcodebuild \
							-scheme "$scheme" \
							-derivedDataPath "$TMPDIR/xcodebuild-$PPID" \
							ENABLE_USER_SCRIPT_SANDBOXING=NO \
							OTHER_SWIFT_FLAGS=--disable-sandbox \
							"$@"
					fi
				EOF
				chmod a+x $out/bin/*
			'';

		in pkgs.writeScriptBin "box" (''#!/bin/sh

			${config.security.sandbox.init}

			# run the user’s interactive shell if there is no other command
			if test "$*" = "" ; then set -- "$SHELL" ; fi

			# wrap some tools so they work inside the sandbox
			PATH=${wrappers}/bin:$PATH

		'' + lib.getAttr pkgs.stdenv.hostPlatform.uname.system {

			Linux = ''
				exec bwrap --unshare-all \
					${ro "ROOT" "/bin"} \
					${ro "ROOT" "/etc"} \
					${ro "ROOT" "/lib"} \
					${ro "ROOT" "/lib64"} \
					${ro "ROOT" "/usr"} \
					${ro "ROOT" "/run/systemd/resolve"} \
			'' + lib.optionalString config.nix.enable ''
					${ro "ROOT" "/nix"} \
			'' + lib.optionalString (config.users.shared.folder != null) ''
					${ro "ROOT" config.users.shared.folder} \
			'' + ''
					${ro "HOME" "/.bashrc"} \
			'' + escapeRules commonSandboxRules + '' \
					${rw "ROOT" "$(readlink -f \"$PWD\")"} \
					--dev /dev \
					--proc /proc \
					--tmpfs /tmp \
					--share-net \
					"$@"
			'';

			# to debug sandbox violations on Darwin:
			# log stream --predicate 'eventMessage CONTAINS "Sandbox:" AND eventMessage CONTAINS "deny"'
			Darwin = ''
				exec sandbox-exec -p '
					(version 1)
					(deny default)
					(debug deny)
					(import "system.sb")

					(allow process-fork process-exec)
					(allow signal (target self) (target children))
					(allow job-creation)

					(allow system-fsctl
						(fsctl-command HFSIOC_SET_HOTFILE_STATE)
					)

					(allow file-read* file-test-existence
						(require-all (file-mode #o0004) (require-not (subpath (param "HOME"))))
						(literal (param "HOME"))
						(literal (param "XDG_CONFIG_HOME"))
						(literal (param "XDG_STATE_HOME"))
						(literal (string-append (param "HOME") "/.CFUserTextEncoding"))
						(literal (string-append (param "HOME") "/.gitconfig"))
						(literal (string-append (param "HOME") "/.local"))
						(literal (string-append (param "HOME") "/.zshenv"))
						(literal (string-append (param "HOME") "/Library"))
						(literal (string-append (param "HOME") "/Library/Caches"))
					)
					${ro "HOME" "/Library/Preferences/com.apple.LaunchServices"}

			'' + lib.optionalString config.programs.xcode.enable ''
					${ro "XDG_CONFIG_HOME" "/swiftpm"}
					${ro "HOME" "/Library/Caches/com.apple.python/Applications/Xcode.app"}
					${ro "HOME" "/Library/Caches/org.swift.swiftpm"}
					${ro "HOME" "/Library/Developer/Xcode/Plug-ins"}
					${ro "HOME" "/Library/org.swift.swiftpm"}
					(allow user-preference-read
						(preference-domain "com.apple.coresimulator")
						(preference-domain "com.apple.dt.xcodebuild")
						(preference-domain "com.apple.dt.xcode")
						(preference-domain "xcodebuild")
					)

			'' + "'" + escapeRules commonSandboxRules + "'" + ''
					(allow file-read-metadata file-test-existence
						(path-ancestors (param "PWD"))
						(subpath "/dev")
					)
					(allow file*
						(subpath (param "PWD"))
						(subpath (string-append (param "TMP") "/C"))
						(subpath (string-append (param "TMP") "/T"))
						(literal "/dev/tty")
						(regex "^/dev/ttys[0-9]*")
					)

					(allow mach-lookup
						(global-name-prefix "com.apple.distributed_notifications")
						(global-name "com.apple.CoreServices.coreservicesd")
						(global-name "com.apple.DiskArbitration.diskarbitrationd")
						(global-name "com.apple.FileCoordination")
						(global-name "com.apple.PowerManagement.control")
						(global-name "com.apple.SystemConfiguration.configd")
						(global-name "com.apple.FSEvents")
						(global-name "com.apple.lsd.mapdb")
						(global-name "com.apple.lsd.modifydb")
						(global-name "com.apple.mobileassetd.v2")
					)
					(allow user-preference-read
						(preference-domain "kCFPreferencesAnyApplication")
					)

					(allow network-outbound
						(remote ip)
			'' + lib.optionalString config.nix.enable ''
						(literal "/nix/var/nix/daemon-socket/socket")
			'' + ''
						(literal "/private/var/run/mDNSResponder")
					)
					(allow network-inbound
						(local ip)
					)
					(system-network)
				' \
					-D HOME="$HOME" \
					-D XDG_BIN_HOME="${prefixVars.XDG_BIN_HOME}" \
					-D XDG_CONFIG_HOME="${prefixVars.XDG_CONFIG_HOME}" \
					-D XDG_STATE_HOME="${prefixVars.XDG_STATE_HOME}" \
					-D PWD="$(readlink -f "$PWD")" \
					-D TMP="$(readlink -f "$TMPDIR/..")" \
					"$@"
			'';
		});
	};
}
