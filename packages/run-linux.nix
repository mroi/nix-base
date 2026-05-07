# bring up an ephemeral VM to run Linux commands on macOS
{ stdenvNoCC, path, container, writeScript }:

let
	linuxPkgs = import path {
		system = builtins.replaceStrings [ "darwin" ] [ "linux" ] stdenvNoCC.hostPlatform.system;
	};

in writeScript "run-linux" ''#!/bin/sh
	if test $# = 0 ; then
		echo "Usage: $0 <Linux Binary> [Arguments]"
		exit 1
	fi

	# setup temporary directory
	TMPDIR=''${TMPDIR:-/tmp}/run-linux-$$
	trap 'rm -rf "$TMPDIR"' EXIT HUP INT TERM QUIT

	# run macOS container command to spawn ephemeral VM
	cd "$TMPDIR"
	${container}/bin/container help

	# simple docker container can run shell and passes exit code:
	# container system start
	# container run -it --rm shell
	# container system stop

	# TODO: test virtiofs to share Nix store and current directory in the container
	# TODO: put things to together to run a linux command
	# TODO: automate the bringup of the container (container system start, image creation)
	# TODO: automatic shutdown of the container system?
	# TODO: replace the container image with a Nix build
	# TODO: replace the kernel with a Nix kernel
	# TODO: reduce container infrastructure: launch container without apiserver
''
