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
		trace sudo diskutil enableOwnership /nix
	fi
	# setup /nix directory
	makeDir 755:root:wheel:hidden /nix
	# disable Spotlight indexing
	if ! test -f /nix/.metadata_never_index ; then
		trace sudo mdutil -i off /nix
		trace sudo touch /nix/.metadata_never_index
		trace sudo rm -rf /nix/.Spotlight-V100
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
	/nix/var/nix/gcroots/per-user/root \
	/nix/var/nix/profiles \
	/nix/var/nix/profiles/per-user
if $isDarwin ; then
	makeDir 750:root:staff /nix/var/nix/daemon-socket
else
	makeDir 755:root:nix /nix/var/nix/daemon-socket
fi
makeDir 1777:root:nix /nix/var/tmp

# Nix configuration file
if ! test "$nixConfigFile" ; then
	if test -f /nix/nix.conf ; then
		nixConfigFile=/nix/nix.conf
	else
		cat > nix.conf <<- EOF
			experimental-features = nix-command flakes
			use-xdg-base-directories = true

			build-users-group = nix
			keep-build-log = false
			sandbox = relaxed
		EOF
		nixConfigFile=nix.conf
	fi
fi
updateFile 644:root:nix /nix/nix.conf "$nixConfigFile"
if updateDidModify ; then restartService nix-daemon ; fi

# Nix daemon SSH configuration
if test "$sshConfigFile" -a "$sshKnownHostsFile" ; then
	makeDir 755:root:nix /nix/var/ssh
	updateFile 644:root:nix /nix/var/ssh/config "$sshConfigFile"
	updateFile 644:root:nix /nix/var/ssh/known_hosts "$sshKnownHostsFile"
fi

# download initial store
if ! test -f /nix/var/nix/db/db.sqlite ; then
	if $isLinux ; then
		url=https://hydra.nixos.org/job/nix/master/binaryTarball.x86_64-linux/latest/download/1
		trace wget --progress=bar:force:noscroll --no-hsts --output-document=nix.tar $url
		trace sudo tar -x --file=nix.tar --directory=/nix/store --group=nix --strip-components=2 --wildcards nix-\*/store
		# shellcheck disable=SC2211
		tar -x --file=nix.tar --to-stdout --wildcards nix-\*/.reginfo | trace sudo /nix/store/*-nix-*/bin/nix-store --load-db
	fi
	if $isDarwin ; then
		url=https://hydra.nixos.org/job/nix/master/binaryTarball.x86_64-darwin/latest/download/1
		trace curl --location --output nix.tar $url
		trace sudo tar -x --file nix.tar --directory /nix/store --gname nix --strip-components 2 nix-\*/store
		# shellcheck disable=SC2211
		tar -x --file nix.tar --to-stdout nix-\*/.reginfo | trace sudo /nix/store/*-nix-*/bin/nix-store --load-db
	fi
	rm nix.tar
fi

# initialize root profile
if ! test -L /nix/var/nix/gcroots/per-user/root/profile ; then
	trace sudo mkdir -p -m 700 ~root/.nix
	trace sudo mkdir -p -m 755 ~root/.nix/profile ~root/.nix/profile/bin
	if ! sudo test -e ~root/.nix/profile/bin/nix ; then
		trace sudo ln -s "$(find /nix/store/*-nix-*/bin/nix | head -n1)" ~root/.nix/profile/bin/
	fi
fi
# gcroot for root profile
makeLink 755:root:nix ~root/.nix/profile /nix/var/nix/gcroots/per-user/root/profile

# run Nix daemon as a background service
if $isLinux ; then
	sslCertFile=/etc/ssl/certs/ca-certificates.crt
	socket=/nix/var/nix/daemon-socket/socket
fi
if $isDarwin ; then
	sslCertFile=/etc/ssl/cert.pem
	objcVariable=OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
	socket=
fi
createService << EOF
	name=nix-daemon ; label=org.nixos.nix-daemon
	description='Nix Package Manager Daemon'
	command=~root/.nix/profile/bin/nix\ --extra-experimental-features\ nix-command\ daemon
	environment="\
		NIX_CONF_DIR=/nix
		NIX_SSHOPTS=-F /nix/var/ssh/config
		NIX_SSL_CERT_FILE=$sslCertFile
		$objcVariable
		TMPDIR=/nix/var/tmp
		XDG_CACHE_HOME=/nix/var
	"
	group=nix ; socket=$socket ; waitForPath=/nix/store
EOF

# ensure Nix command is runnable
if ! command -v nix > /dev/null ; then
	nixBinary=$(find /nix/store/*-nix-*/bin/nix | sort --field-separator=- --key=3 | tail -n1)
	nix() {	NIX_CONF_DIR=/nix "$nixBinary" "$@" ; }
fi
