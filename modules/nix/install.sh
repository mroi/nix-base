storeHeading 'Installing the Nix package manager'

rootStagingDir=${rootStagingDir:-${XDG_STATE_HOME:-$HOME/.local/state}/rebuild}

if $isDarwin ; then
	# setup firmlink in root directory
	if ! test -d /nix ; then
		if ! grep -Fqx nix /etc/synthetic.conf 2> /dev/null ; then
			trace sudo sh -c 'echo nix >> /etc/synthetic.conf'
		fi
		trace sudo /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t || true
		test -d /nix || fatalError 'Creating /nix firmlink failed'
	fi
	# obtain Nix volume password
	if test -f "$rootStagingDir/login-hook.sh" ; then
		if grep -qF 'NIX_VOLUME_PASSWORD=' "$rootStagingDir/login-hook.sh" ; then
			password=$(sed -nE '/NIX_VOLUME_PASSWORD=/{s/^[^=]*=([^[:space:]#]*)/\1/;p;}' "$rootStagingDir/login-hook.sh")
		else
			echo 'NIX_VOLUME_PASSWORD=' >> "$rootStagingDir/login-hook.sh"
		fi
	else
		mkdir -p "$rootStagingDir"
		echo 'NIX_VOLUME_PASSWORD=' > "$rootStagingDir/login-hook.sh"
	fi
	if test -z "$password" ; then
		password=$(dd if=/dev/urandom bs=24 count=1 2> /dev/null | base64)
		sed -i_ "/NIX_VOLUME_PASSWORD=/{s|=.*|=$password|;}" "$rootStagingDir/login-hook.sh"
		rm "$rootStagingDir/login-hook.sh_"
	fi
	# create the Nix volume
	if ! diskutil list Nix > /dev/null 2>&1 ; then
		container=$(diskutil info -plist / | xmllint --xpath '/plist/dict/key[text()="ParentWholeDisk"]/following-sibling::string[1]/text()' -)
		test "$container" != "${container#disk}" || fatalError 'Could not find primary APFS container'
		echo "$password" | trace sudo diskutil apfs addVolume "$container" APFSX Nix -stdinpassphrase -mountpoint /nix
		diskutil list Nix > /dev/null 2>&1 || fatalError 'Could not create the Nix volume'
	fi
	# Nix volume should be mounted
	if test "$(stat -f %d /)" = "$(stat -f %d /nix)" ; then
		fatalError 'The Nix volume is not mounted'
	fi
	# enable file ownership on the Nix volume
	ownershipStatus=$(diskutil info -plist Nix | xmllint --xpath '/plist/dict/key[text()="GlobalPermissionsEnabled"]/following-sibling::*[1]' -)
	if ! test "$ownershipStatus" = "<true/>" ; then
		trace diskutil enableOwnership /nix
	fi
	# setup /nix directory
	makeDir 755:root:wheel:hidden /nix
	# disable Spotlight indexing
	if ! test -f /nix/.metadata_never_index ; then
		trace sudo mdutil -i off /nix
		trace sudo touch /nix/.metadata_never_index
	fi
	# disable fsevents logging
	if ! test -f /nix/.fseventsd/no_log ; then
		trace sudo rm -rf /nix/.fseventsd
		trace sudo mkdir /nix/.fseventsd
		trace sudo touch /nix/.fseventsd/no_log
	fi
	# disable Trash directory
	if ! test -f /nix/.Trashes ; then
		trace sudo rm -rf /nix/.Trashes
		trace sudo touch /nix/.Trashes
	fi
fi

# create nix group and user
createGroup << EOF
	name=nix ; gid=600 ; description='Nix Build Group'
EOF
createUser << EOF
	name=_nix ; uid=600 ; gid=600 ; group=nix ; isHidden=1
	home=$(if $isDarwin ; then echo /var/empty ; else echo /nonexistent ; fi)
	shell=$(if $isDarwin ; then echo /usr/bin/false ; else echo /usr/sbin/nologin ; fi)
	description='Nix Build User'
EOF
createGroup << EOF
	name=nix ; gid=600 ; members=_nix ; description='Nix Build Group'
EOF

# directory structure
if $isLinux ; then
	makeDir 755:root:root /nix
fi
makeDir 1775:root:nix /nix/store
makeDir 755:root:nix \
	/nix/var \
	/nix/var/nix \
	/nix/var/nix/gcroots \
	/nix/var/nix/gcroots/per-user \
	/nix/var/nix/gcroots/per-user/root
if $isDarwin ; then
	makeDir 750:root:staff /nix/var/nix/daemon-socket
else
	makeDir 755:root:nix /nix/var/nix/daemon-socket
fi
makeDir 755:_nix:nix /nix/var/tmp

setup_nix() {
	# Nix configuration file
	if ! test -r /nix/nix.conf ; then
		cat > /nix/nix.conf <<- EOF
			experimental-features = nix-command flakes
			use-xdg-base-directories = true

			build-users-group = nix
			keep-build-log = false
			sandbox = relaxed

			# the darwin.builder Linux VM has to be started manually on port 33022
			builders = builder-linux x86_64-linux,aarch64-linux - - - big-parallel,kvm
			builders-use-substitutes = true
		EOF
		# trusted-substituters = ssh://user@server to use another machine’s store as cache.
		#   On the client, you need to put an SSH identity and known_hosts file in /nix/var/ssh.
		#   On the server, you can restrict this SSH identity to run "nix-store --serve --write".
		# trusted-public-keys (client) and secret-key-files (server) for signing.
		#   See "nix key generate-secret --help".
		#   Make sure to add the public key of the default Nix binary cache as well:
		#   cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
	fi
	# setup SSH for operations performed by the Nix daemon
	if ! test -d /nix/var/ssh ; then
		mkdir /nix/var/ssh
		cat > /nix/var/ssh/config <<- EOF
			UserKnownHostsFile /nix/var/ssh/known_hosts

			Host builder-linux
			Hostname localhost
			Port 33022
			User builder
			IdentityFile /nix/var/ssh/builder_ed25519
		EOF
		cat > /nix/var/ssh/known_hosts <<- EOF
			[localhost]:33022 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBWcxb/Blaqt1auOtE+F8QUWrUotiC5qBJ+UuEWdVCb
		EOF
		ssh-keygen -q -t ed25519 -N '' -C '' -f /nix/var/ssh/builder_ed25519
		chgrp -R nix /nix/var/ssh
	fi
	# download initial store
	if ! test -f /nix/var/nix/db/db.sqlite ; then
		curl -Lo ~/nix.tar https://hydra.nixos.org/job/nix/master/binaryTarball.x86_64-darwin/latest/download/1
		tar -x -f ~/nix.tar -C /nix/store --gname nix --strip-components 2 nix-\*/store
		# shellcheck disable=SC2211
		tar -xO -f ~/nix.tar nix-\*/.reginfo | /nix/store/*-nix-*/bin/nix-store --load-db
		rm ~/nix.tar
	fi
	# initialize root profile
	if ! test -e ~/.nix/profile/bin ; then
		test -d ~/.nix || mkdir -m 700 ~/.nix
		test -d ~/.nix/profile || mkdir -m 755 ~/.nix/profile
		test -d ~/.nix/profile/bin || mkdir -m 755 ~/.nix/profile/bin
		ln -s "$(find /nix/store/*-nix-*/bin/nix | head -n1)" ~/.nix/profile/bin/
	fi
	# gcroot for root profile
	test -L /nix/var/nix/gcroots/per-user/root/profile || \
		ln -s ~/.nix/profile /nix/var/nix/gcroots/per-user/root/profile
	# launch nix daemon at boot
	if ! test -r /Library/LaunchDaemons/org.nixos.nix-daemon.plist ; then
		plutil -convert xml1 -o /Library/LaunchDaemons/org.nixos.nix-daemon.plist - <<- EOF
			{
				"EnvironmentVariables": {
					"NIX_CONF_DIR": "/nix",
					"NIX_SSHOPTS": "-F /nix/var/ssh/config",
					"NIX_SSL_CERT_FILE": "/etc/ssl/cert.pem",
					"OBJC_DISABLE_INITIALIZE_FORK_SAFETY": "YES",
					"TMPDIR": "/nix/var/tmp",
					"XDG_CACHE_HOME": "/nix/var"
				},
				"GroupName": "nix",
				"KeepAlive": true,
				"Label": "org.nixos.nix-daemon",
				"ProgramArguments": [
					"/bin/sh",
					"-c",
					"/bin/wait4path /nix/store && exec /var/root/.nix/profile/bin/nix --extra-experimental-features nix-command daemon"
				],
				"RunAtLoad": true,
				"StandardErrorPath": "/dev/null",
				"StandardOutPath": "/dev/null"
			}
		EOF
		launchctl bootstrap system /Library/LaunchDaemons/org.nixos.nix-daemon.plist
	fi
}
