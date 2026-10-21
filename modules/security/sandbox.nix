{ config, lib, pkgs, ... }: {

	# this sandbox should implement the following security policy:
	# * credentials and user files are not readable or writable from the sandbox,
	#   except in explicitly exposed locations (e.g. PWD or config/state directories)
	# * no data can be exfiltrated by writing to locations readable by other users,
	#   a deliberate exception are writes to the Nix store by invoking the Nix daemon
	# * data exfiltration to the internet is out of scope (currently not restricted)

	options.security.sandbox = {
		enable = lib.mkEnableOption "developer sandbox command";
		init = lib.mkOption {
			type = lib.types.lines;
			default = "";
			description = "Shell code to execute at the beginning of the sandbox script.";
		};
		rules = lib.mkOption {
			type = lib.types.functionTo (lib.types.listOf lib.types.str);
			default = _: [];
			example = lib.literalExpression "{ ro, rw }: [ (ro \"HOME\" \"/.vimrc\") ]";
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
			commonSandboxRules = [
				(ro "XDG_BIN_HOME" "")
			] ++ lib.optionals (isInstalled "fish") [
				(ro "XDG_CONFIG_HOME" "/fish")
				(rw "XDG_STATE_HOME" "/fish")
			] ++ lib.optionals (isInstalled "git" || config.programs.xcode.enable) [
				(ro "XDG_CONFIG_HOME" "/git/config")
			] ++ lib.optionals (isInstalled "micro") [
				(ro "XDG_CONFIG_HOME" "/micro")
				(rw "XDG_CONFIG_HOME" "/micro/backups")
				(rw "XDG_CONFIG_HOME" "/micro/buffers")
			] ++ lib.optionals (isInstalled "opencode") [
				(ro "XDG_CONFIG_HOME" "/opencode")
				(rw "XDG_STATE_HOME" "/opencode")
			] ++ lib.optionals (config.environment.profile != []) [
				(ro "XDG_STATE_HOME" "/nix")
			] ++ lib.optionals (config.users.shared.folder != null) [
				(ro "ROOT" config.users.shared.folder)
			] ++ config.security.sandbox.rules { inherit ro rw; };

			# wrap dev tools whose behavior collides with the sandbox
			wrappers = pkgs.runCommand "sandbox-wrappers" {} (''
				mkdir -p $out/bin

			'' + lib.optionalString (isInstalled "swift" || config.programs.xcode.enable) ''
				# swift needs --disable-sandbox
				cat <<- EOF > $out/bin/swift
					#!/bin/sh
					swift() {
						# find the original swift binary in PATH
						unset -f swift
						swift=\$(PATH="\''${PATH#*$out/bin:}" command -v swift)
						if test "\$swift" ; then
							exec "\$swift" "\$@"
						else
							echo "sandbox swift wrapper: no swift binary found in PATH" >&2
							exit 127
						fi
					}
					if test "\$#" -eq 0 -o "\$1" != "\''${1#-}" ; then
						# invocation without subcommand
						swift "\$@"
					else
						# invocation with subcommand
						subcommand=\$1 ; shift
						swift "\$subcommand" --disable-sandbox "\$@"
					fi
				EOF

			'' + lib.optionalString config.programs.xcode.enable ''
				cat <<- 'EOF' > $out/bin/xcodebuild
					#!/bin/sh
					if test "''${*#*-scheme }" != "$*" ; then
						# explicit scheme option given
						SWIFTPM_DISABLE_SANDBOX=1 exec /usr/bin/xcodebuild \
							-derivedDataPath "$TMPDIR/xcodebuild-$PPID" \
							ENABLE_USER_SCRIPT_SANDBOXING=NO \
							OTHER_SWIFT_FLAGS=-disable-sandbox \
							"$@"
					else
						# use first available scheme
						scheme=$(ls -d *.xcodeproj/xcshareddata/xcschemes/*.xcscheme *.xcodeproj 2> /dev/null | head -n1)
						scheme=$(basename "$scheme" .xcscheme)
						scheme=$(basename "$scheme" .xcodeproj)
						SWIFTPM_DISABLE_SANDBOX=1 exec /usr/bin/xcodebuild \
							-scheme "$scheme" \
							-derivedDataPath "$TMPDIR/xcodebuild-$PPID" \
							ENABLE_USER_SCRIPT_SANDBOXING=NO \
							OTHER_SWIFT_FLAGS=-disable-sandbox \
							"$@"
					fi
				EOF
			'' + ''
				find $out/bin -type f -exec chmod a+x {} \;
			'');

		in pkgs.writeScriptBin "box" (''#!/bin/sh

			${config.security.sandbox.init}

			# run the user’s interactive shell if there is no other command
			if test "$*" = "" ; then set -- "$SHELL" ; fi

			# wrap some tools so they work inside the sandbox
			PATH=${wrappers}/bin:$PATH

			# normalize paths by resolving symlinks
			resolve() {
				if ! test -e "$1" ; then echo "sandbox: $1 does not exist" >&2 ; fi
				if test -d "$1" ; then
					dir=$1 ; file=
				else
					dir=''${1%/*} ; file=/''${1##*/}
				fi
				save=$PWD
				cd -P -- "$dir" || return 1
				echo "$(pwd -P)$file"
				cd -- "$save"
			}

		'' + lib.getAttr pkgs.stdenv.hostPlatform.uname.system {

			Linux = ''
				exec bwrap --unshare-all \
					${ro "ROOT" "/bin"} \
					${ro "ROOT" "/etc"} \
					${ro "ROOT" "/lib"} \
					${ro "ROOT" "/usr"} \
					${ro "ROOT" "/run/systemd/resolve"} \
			'' + lib.optionalString pkgs.stdenv.hostPlatform.isx86_64 ''
					${ro "ROOT" "/lib64"} \
			'' + lib.optionalString config.nix.enable ''
					${ro "ROOT" "/nix"} \
			'' + ''
					${ro "HOME" "/.bashrc"} \
			'' + escapeRules (lib.concatLines commonSandboxRules) + '' \
					${rw "ROOT" "$(resolve \"$PWD\")"} \
					--dev /dev \
					--proc /proc \
					--tmpfs /tmp \
					--share-net \
					"$@"
			'';

			# to debug sandbox violations on Darwin:
			# log stream --predicate 'eventMessage CONTAINS "Sandbox:" AND eventMessage CONTAINS "deny"'
			Darwin = ''
				# redirect TMPDIR to a custom directory, which is deleted after use
				tmp=$(mktemp -d -t TemporaryDirectory)
				trap "rm -rf \"$tmp\"" EXIT HUP TERM QUIT

				TMPDIR="$tmp" sandbox-exec -p '
					(version 1)
					(deny default)
					(debug deny)
					(import "system.sb")

					(allow process-fork process-exec)
					(allow signal (target self) (target children))

					(allow system-fsctl
						(fsctl-command HFSIOC_SET_HOTFILE_STATE)
					)

					(allow file-read* file-test-existence
						(literal (param "HOME"))
						(literal (param "XDG_BIN_HOME"))
						(literal (param "XDG_CONFIG_HOME"))
						(literal (param "XDG_STATE_HOME"))
						(path-ancestors (param "HOME"))
						(path-ancestors (param "XDG_BIN_HOME"))
						(path-ancestors (param "XDG_CONFIG_HOME"))
						(path-ancestors (param "XDG_STATE_HOME"))
						(path-ancestors (param "PWD"))
						(subpath "/dev")
					)
					(allow file-read* file-test-existence
						(require-all (file-mode #o0004)
							(require-not (subpath (param "HOME")))
							(require-not (subpath "/Users"))
							(require-not (subpath "/private/tmp"))
							(require-not (subpath "/private/var/tmp"))
						)
						(literal (string-append (param "HOME") "/.CFUserTextEncoding"))
						(literal (string-append (param "HOME") "/.gitconfig"))
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
					(allow file-read-metadata
						(literal (string-append (param "TMP") "/T"))
					)
					(allow file-read*
						(literal (string-append (param "TMP") "/T/xcrun_db"))
					)
					; FIXME: these write targets are undesired, but necessary for swift builds
					(allow file*
						(subpath (string-append (param "TMP") "/C/clang/ModuleCache"))
						(subpath (string-append (param "TMP") "/T/TemporaryItems"))
						(regex (string-append "^" (regex-quote (param "TMP")) "/T/TemporaryDirectory\..*"))
						(regex (string-append "^" (regex-quote (param "TMP")) "/T/swbuild\.tmp\..*"))
					)
					(allow user-preference-read
						(preference-domain "com.apple.coresimulator")
						(preference-domain "com.apple.dt.xcodebuild")
						(preference-domain "com.apple.dt.xcode")
						(preference-domain "xcodebuild")
					)

			'' + "'" + escapeRules (lib.concatLines commonSandboxRules) + "'" + ''

					(allow file*
						(subpath (param "PWD"))
						(literal (param "TTY"))
						(literal "/dev/tty")
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
					-D ROOT="" \
					-D HOME="$HOME" \
					-D XDG_BIN_HOME="${prefixVars.XDG_BIN_HOME}" \
					-D XDG_CONFIG_HOME="${prefixVars.XDG_CONFIG_HOME}" \
					-D XDG_STATE_HOME="${prefixVars.XDG_STATE_HOME}" \
					-D PWD="$(resolve "$PWD")" \
					-D TMP="$(resolve "$TMPDIR/..")" \
					-D TTY="$(tty 2>/dev/null || echo /dev/null)" \
					"$@"
			'';
		});
	};
}
