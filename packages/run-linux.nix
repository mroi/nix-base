# bring up an ephemeral VM to run Linux commands on macOS
{ stdenvNoCC, path }:

let
	# TODO: we are using the last commit of vmTools using 9p for shared file systems
	# commits since a8032f78ada76191673433db713e6fd725ca35ac use virtiofs, but no
	# virtiofsd exists for macOS yet (https://gitlab.com/virtio-fs/virtiofsd/-/issues/169)
	path = builtins.fetchGit {
		url = "https://github.com/NixOS/nixpkgs.git";
		rev = "581db02151b5cf62bfde2949f01ce36e63c10547";
		shallow = true;
	};

	host = import path { inherit (stdenvNoCC.hostPlatform) system; };
	linuxPkgs = import path {
		system = builtins.replaceStrings [ "darwin" ] [ "linux" ] stdenvNoCC.hostPlatform.system;
	};

	vmTools = host.vmTools.override {
		# instead of full cross compilation: surgically replace some packages with host versions
		pkgs = linuxPkgs // {
			makeInitrd = host.makeInitrd;
			writeScript = host.writeScript;
			buildPackages = linuxPkgs.buildPackages // {
				qemu_kvm = host.qemu_kvm;
			};
		};
	};

	qemuSerialDevice = if stdenvNoCC.hostPlatform.isx86 then "isa-serial" else "pci-serial";

in host.writeScript "run-linux" ''#!/bin/sh
	if test $# = 0 ; then
		echo "Usage: $0 <Linux Binary> [Arguments]"
		exit 1
	fi

	# setup temporary directory
	TMPDIR=''${TMPDIR:-/tmp}/run-linux-$$
	trap 'rm -rf "$TMPDIR"' EXIT HUP INT TERM QUIT
	mkdir -p "$TMPDIR/xchg"

	# this script is sourced within Linux
	cat <<- EOF > "$TMPDIR/xchg/saved-env"

		# pass environment variables from host
		$(export)
		unset PS1 PS2 PS4

		# mount current host directory at same path
		${linuxPkgs.coreutils}/bin/mkdir -p "$PWD"
		${linuxPkgs.busybox}/bin/mount -t 9p cwd "$PWD" -o trans=virtio,version=9p2000.L,msize=131072

		# configure the network
		export MODULE_DIR=${linuxPkgs.linux}/lib/modules/
		${linuxPkgs.kmod}/bin/modprobe virtio_net
		${linuxPkgs.busybox}/bin/ip link set eth0 up
		${linuxPkgs.busybox}/bin/ip addr add 10.0.2.10/24 dev eth0
		${linuxPkgs.busybox}/bin/ip route add default via 10.0.2.2
		echo "nameserver 10.0.2.3" > /etc/resolv.conf

		# initialize stage2 environment
		stdenv=${linuxPkgs.stdenvNoCC}
		out=/tmp

		# setup command to execute and redirect stdio
		command="$(for arg ; do echo "$arg" ; done)"
		function runCommand() { set +e ; cd "$PWD" ; IFS=$'\n' ; \$command > /dev/ttyS1 2> /dev/ttyS1 < /dev/ttyS1 ; }
		origBuilder=runCommand
	EOF

	# add extra QEMU options:
	# separate between kernel console and stdio, export current host directory, enable networking
	QEMU_OPTS="
		-m 512M
		-machine accel=hvf
		-monitor none
		-serial none
		-chardev file,id=console,path=$TMPDIR/console.log
		-chardev stdio,id=stdio,signal=on
		-device ${qemuSerialDevice},chardev=console
		-device ${qemuSerialDevice},chardev=stdio
		-virtfs local,path=$PWD,security_model=none,mount_tag=cwd
		-nic user,model=virtio
	"

	# run Nix’ default QEMU command
	cd "$TMPDIR"
	${vmTools.qemuCommandLinux} 2> /dev/null

	# handle exit code
	if ! test -e "$TMPDIR/xchg/in-vm-exit"; then
		echo "Virtual machine didn't produce an exit code."
		exit 1
	fi
	exit "$(cat "$TMPDIR/xchg/in-vm-exit")"
''
