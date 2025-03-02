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
	# create the Nix volume
	createVolume <<- EOF
		name=Nix ; mountPoint=/nix ; container=/
		fsType=APFSX ; encrypted=1 ; ownership=1
		keyStorage="$rootStagingDir/login-hook.sh" ; keyVariable=NIX_VOLUME_PASSWORD
	EOF
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
if updateDidCreate || updateDidModify ; then restartService nix-daemon ; fi

# Nix daemon SSH configuration
if test "$sshConfigFile" -a "$sshKnownHostsFile" ; then
	makeDir 755:root:nix /nix/var/ssh
	updateFile 644:root:nix /nix/var/ssh/config "$sshConfigFile"
	updateFile 644:root:nix /nix/var/ssh/known_hosts "$sshKnownHostsFile"
fi

# download initial store
if ! test -f /nix/var/nix/db/db.sqlite ; then
	if $isLinux ; then
		if $isx86_64 ; then
			url=https://hydra.nixos.org/job/nix/master/binaryTarball.x86_64-linux/latest/download/1
		else
			url=https://hydra.nixos.org/job/nix/master/binaryTarball.aarch64-linux/latest/download/1
		fi
		trace wget --progress=bar:force:noscroll --no-hsts --output-document=nix.tar "$url"
		trace sudo tar -x --file=nix.tar --directory=/nix/store --group=nix --strip-components=2 --wildcards nix-\*/store
		# shellcheck disable=SC2211
		tar -x --file=nix.tar --to-stdout --wildcards nix-\*/.reginfo | trace sudo --set-home /nix/store/*-nix-*/bin/nix-store --option build-users-group nix --load-db
	fi
	if $isDarwin ; then
#		FIXME: current master build creates broken manifest.json files in profiles on Darwin
#		url=https://hydra.nixos.org/job/nix/master/binaryTarball.x86_64-darwin/latest/download/1
		if $isx86_64 ; then
			url=https://hydra.nixos.org/build/274231650/download/1/nix-2.25.0pre20241001_96ba7f9-x86_64-darwin.tar.xz
		else
			url=https://hydra.nixos.org/build/274231650/download/1/nix-2.25.0pre20241001_96ba7f9-aarch64-darwin.tar.xz
		fi
		trace curl --location --output nix.tar "$url"
		trace sudo tar -x --file nix.tar --directory /nix/store --gname nix --strip-components 2 nix-\*/store
		# shellcheck disable=SC2211
		tar -x --file nix.tar --to-stdout nix-\*/.reginfo | trace sudo --set-home /nix/store/*-nix-*/bin/nix-store --option build-users-group nix --load-db
	fi
	trace sudo chmod -R a-w /nix/store/*
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
while ! test -S /nix/var/nix/daemon-socket/socket ; do sleep 1 ; done
