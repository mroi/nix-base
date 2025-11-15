# file and directory creation

_parsePermissions() {
	# parse permission descriptor <perms>:<owner>:<group>:<flags>
	unset _perms _owner _group _flags _statFormatLinux __statFormatDarwin _statExpected _sudo

	_descriptor=$1
	_perms=${_descriptor%%:*}
	if test "$_descriptor" != "${_descriptor#*:}" ; then
		_descriptor=${_descriptor#*:}
		_owner=${_descriptor%%:*}
		if test "$_descriptor" != "${_descriptor#*:}" ; then
			_descriptor=${_descriptor#*:}
			_group=${_descriptor%%:*}
			if test "$_descriptor" != "${_descriptor#*:}" ; then
				_flags=${_descriptor#*:}
			fi
		fi
	fi

	if test "$_perms" ; then
		_statFormatLinux=%a
		_statFormatDarwin=%Lp
		_statExpected="$_perms"
	fi
	if test "$_owner" ; then
		_statFormatLinux=$_statFormatLinux:%U
		_statFormatDarwin=$_statFormatDarwin:%Su
		_statExpected="$_statExpected:$_owner"
	fi
	if test "$_group" ; then
		_statFormatLinux=$_statFormatLinux:%G
		_statFormatDarwin=$_statFormatDarwin:%Sg
		_statExpected="$_statExpected:$_group"
	fi
	if test "$_flags" && $isDarwin ; then
		_statFormatDarwin=$_statFormatDarwin:%Sf
		_statExpected="$_statExpected:$_flags"
	fi

	test -z "$_owner" || _sudo=sudo
}

_setPermissions() {
	# shellcheck disable=SC2086
	if $isLinux ; then
		if test "$_statFormatLinux" && test "$(stat -c "$_statFormatLinux" "$1")" != "$_statExpected" ; then
			test -z "$_perms" || test "$(stat -c %a "$1")" = "$_perms" || trace $_sudo chmod "$(test -d "$1" -a \( -g "$1" -o -u "$1" \) && echo '=')$_perms" "$1"
			test -z "$_owner" || test "$(stat -c %U "$1")" = "$_owner" || trace $_sudo chown -h "$_owner" "$1"
			test -z "$_group" || test "$(stat -c %G "$1")" = "$_group" || trace $_sudo chgrp -h "$_group" "$1"
		fi
	fi
	# shellcheck disable=SC2086
	if $isDarwin ; then
		if test "$_statFormatDarwin" && test "$(stat -f "$_statFormatDarwin" "$1")" != "$_statExpected" ; then
			test -z "$_perms" || test "$(stat -f %Mp%Lp "$1")" -eq "$_perms" || trace $_sudo chmod -h "$_perms" "$1"
			test -z "$_owner" || test "$(stat -f %Su "$1")" = "$_owner" || trace $_sudo chown -h "$_owner" "$1"
			test -z "$_group" || test "$(stat -f %Sg "$1")" = "$_group" || trace $_sudo chgrp -h "$_group" "$1"
			test -z "$_flags" || test "$(stat -f %Sf "$1")" = "$_flags" || trace $_sudo chflags -h "$_flags" "$1"
		fi
	fi
}

makeDir() {
	# first argument: optional permission descriptor
	if test "$1" != "${1#[0-9]}" ; then
		_parsePermissions "$1"
		shift
	else
		_parsePermissions ''
	fi

	for _dir ; do
		_sub=
		_dir=${_dir#/}/
		while test "$_dir" ; do
			# iterate over all subpaths
			_sub=$_sub/${_dir%%/*}
			_dir=${_dir#*/}
			if ! test -d "$_sub" ; then
				# create and apply permissions if not existing
				# shellcheck disable=SC2086
				trace $_sudo mkdir "$_sub"
				_setPermissions "$_sub"
			fi
		done
		# final directory always gets permissions applied
		_setPermissions "$_sub"
	done
}

makeLink() {
	# first argument: optional permission descriptor
	if test "$1" != "${1#[0-9]}" ; then
		_parsePermissions "$1"
		shift
	else
		_parsePermissions ''
	fi

	_link=$1
	_target=$2

	if $isLinux ; then
		_ln='ln -snf'
		# ignore link permissions on Linux
		if test "$_statFormatLinux" != "${_statFormatDarwin#%a:}" ; then
			_statFormatLinux=${_statFormatDarwin#%a:}
			_statExpected=${_statExpected#*:}
			_perms=''
		fi
	fi
	if $isDarwin ; then
		_ln='ln -shf'
	fi

	if ! test -L "$_link" -a "$(readlink "$_link")" = "$_target" ; then
		# shellcheck disable=SC2086
		trace $_sudo $_ln "$_target" "$_link"
	fi
	_setPermissions "$_link"
}

makeFile() {
	# first argument: optional permission descriptor
	if test "$1" != "${1#[0-9]}" ; then
		_parsePermissions "$1"
		shift
	else
		_parsePermissions ''
	fi

	_target=$1
	_source=$2
	_update=none

	if ! test -f "$_target" || ! cmp --quiet "$_source" "$_target" && test "$_source" ; then
		printDiff "$_target" "$_source"
		if ! test -f "$_target" ; then
			_update=created
		else
			_update=modified
		fi
		trace $_sudo cp -a "$_source" "$_target"
	fi
	if ! test -f "$_target" && ! test "$_source" ; then
		# shellcheck disable=SC2086
		trace $_sudo touch "$_target"
		_update=created
	fi
	_setPermissions "$_target"
}

didCreate() {
	if test "$_update" = created ; then return 0 ; else return 1 ; fi
}

didModify() {
	if test "$_update" = modified ; then return 0 ; else return 1 ; fi
}

deleteFile() {
	_deleted=false
	for _file ; do
		if test -e "$_file" ; then
			if test -w "${_file%/*}" ; then
				_sudo=
			else
				_sudo=sudo
			fi
			trace $_sudo rm "$_file"
			_deleted=true
		fi
	done
}

didRemove() {
	if "$_deleted" ; then return 0 ; else return 1 ; fi
}

makeTree() {
	# first argument: optional permission descriptor
	if test "$1" != "${1#[0-9]}" ; then
		makeDir "$1" "$2"
		shift
	else
		makeDir "$1"
	fi

	_target=$1
	_source=$2

	if $isDarwin && ! test -w "$_source" ; then
		# rsync fails to propagate extended attributes if the source is not writable
		mkdir source
		cp -Rc "$_source/" source/
		chmod -RH u+w source/
		_source=source
	fi

	# shellcheck disable=SC2086
	trace $_sudo rsync --recursive --delete --links --executability \
		"$(if $isDarwin ; then echo --extended-attributes ; fi)" "$_source/" "$_target"
	# shellcheck disable=SC2086
	trace $_sudo chmod -R"$(if $isDarwin ; then echo H ; fi)" "$(umask -S | tr x X)" "$_target"

	# shellcheck disable=SC2086
	test -z "$_owner" || trace $_sudo chown -Rh "$_owner" "$1"
	# shellcheck disable=SC2086
	test -z "$_group" || trace $_sudo chgrp -Rh "$_group" "$1"

	rm -rf source
}

# extended attributes

makeAttr() {
	_target=$1
	_attr=$2
	_value=$3

	if test -w "$_target" ; then
		_sudo=
	else
		_sudo=sudo
	fi

	if $isDarwin ; then
		if test "$(xattr -p "$_attr" "$_target" 2> /dev/null)" != "$_value" ; then
			trace $_sudo xattr -w "$_attr" "$_value" "$_target"
		fi
	fi
}

makeFinderInfo() {
	# supported finder info type: flag
	_target=$1
	_type=$2
	_info=$3

	if test -w "$_target" ; then
		_sudo=
	else
		_sudo=sudo
	fi

	if $isDarwin ; then
		case "$_type" in
			flag)
				if xcode-select -p > /dev/null 2>&1 ; then
					case "$(GetFileInfo -a "$_target")" in
						*$_info*) ;;
						*) trace $_sudo SetFile -a "$_info" "$_target" ;;
					esac
				else
					printError "Unable to set Finder flags: $_target"
					printInfo 'Finder flags require Xcode command line tools'
				fi
				;;
		esac
	fi
}

makeIcon() {
	_target=$1
	_icon=$2

	if test -w "$_target" ; then
		_sudo=
	else
		_sudo=sudo
	fi

	if $isDarwin ; then
		if test -f "$_icon" ; then
			if ! test -f "$_target"/Icon? ; then
				trace $_sudo ditto -xz "$_icon" "$_target"/
			fi
		else
			makeAttr "$_target" com.apple.icon.folder\#S "{\"sym\":\"$_icon\"}"
		fi
		makeFinderInfo "$_target" flag C
	else
		fatalError 'No folder icon support on Linux'
	fi
}

# volume management

makeVolume() {
	name= ; container= ; encrypted= ; keyStorage= ; keyVariable= ; fsType= ; mountPoint= ; ownership= ; hidden=
	# shellcheck disable=SC1091
	. /dev/stdin  # read named parameters
	if $isDarwin ; then
		if test "$encrypted" ; then
			# obtain volume password
			_password=
			if test -f "$keyStorage" ; then
				if grep -qF "${keyVariable}=" "$keyStorage" ; then
					_password=$(sed -nE "/${keyVariable}=/ { s/^[^=]*=([^[:space:]#]*)/\1/ ; p ; }" "$keyStorage")
				else
					echo "${keyVariable}=" >> "$keyStorage"
				fi
			else
				mkdir -p "${keyStorage%/*}"
				echo "${keyVariable}=" > "$keyStorage"
			fi
			if test -z "$_password" ; then
				_password=$(dd if=/dev/urandom bs=24 count=1 2> /dev/null | base64)
				sed -i_ "/${keyVariable}=/ { s|=.*|=${_password}| ; }" "$keyStorage"
				rm "${keyStorage}_"
			fi
		fi
		# create the volume
		if ! diskutil list "$name" > /dev/null 2>&1 ; then
			container=$(diskutil info -plist "$container" | plutil -extract ParentWholeDisk raw -)
			test "$container" != "${container#disk}" || fatalError "Could not find APFS container for volume $name"
			if test "$encrypted" ; then
				if test "$mountPoint" = "/Volumes/$name" ; then
					echo "$_password" | trace sudo diskutil apfs addVolume "$container" "$fsType" "$name" -stdinpassphrase
				else
					echo "$_password" | trace sudo diskutil apfs addVolume "$container" "$fsType" "$name" -stdinpassphrase -mountpoint "$mountPoint"
				fi
			else
				if test "$mountPoint" = "/Volumes/$name" ; then
					trace sudo diskutil apfs addVolume "$container" "$fsType" "$name"
				else
					trace sudo diskutil apfs addVolume "$container" "$fsType" "$name" -mountpoint "$mountPoint"
				fi
			fi
			diskutil list "$name" > /dev/null 2>&1 || fatalError "Could not create the volume $name"
		fi
		# volume should be mounted
		if test "$(stat -f %d /)" = "$(stat -f %d "$mountPoint")" ; then
			fatalError "The volume $name is not mounted"
		fi
		# enable file ownership on the volume
		_ownershipStatus=$(diskutil info -plist "$name" | plutil -extract GlobalPermissionsEnabled raw -)
		case "$_ownershipStatus,$ownership" in
			'true,') trace sudo diskutil disableOwnership "$mountPoint" ;;
			'true,1') ;;
			'false,') ;;
			'false,1') trace sudo diskutil enableOwnership "$mountPoint" ;;
			*) fatalError "Inconsistent ownership status on the volume $name" ;;
		esac
		# hidden flag
		hidden=$(if test "$hidden" ; then echo hidden ; else echo - ; fi)
		if test "$(stat -f %Sf "$mountPoint")" != "$hidden" ; then
			trace sudo chflags "$hidden" "$mountPoint"
		fi
	fi
	unset name container encrypted keyStorage keyVariable fsType mountPoint ownership hidden
}

deleteVolume() {
	if $isDarwin ; then
		trace diskutil unmount "$1"
		trace sudo diskutil apfs deleteVolume "$1"
	fi
}

# user and group management

makeUser() {
	name= ; uid= ; gid= ; group= ; isHidden= ; home= ; shell= ; description=
	# shellcheck disable=SC1091
	. /dev/stdin  # read named parameters
	if $isLinux ; then
		if ! test "$gid" ; then
			gid=$(getent group "$group" | cut -d: -f3)
		fi
		if ! getent passwd "$name" > /dev/null ; then
			trace sudo adduser \
				--uid "$uid" \
				--ingroup "$group" \
				--home "$home" \
				--shell "$shell" \
				--gecos "$description" \
				--no-create-home \
				--disabled-password \
				--force-badname \
				"$name"
		fi
		if ! getent passwd "$name" | grep -q "^$name:x:$uid:$gid:$description,,,:$home:$shell$" ; then
			deleteUser "$name"
			makeUser <<- EOF
				name="$name" ; uid="$uid" ; gid="$gid" ; group="$group" ; isHidden="$isHidden" ; home="$home" ; shell="$shell" ; description="$description"
			EOF
		fi
	fi
	if $isDarwin ; then
		if ! test "$gid" ; then
			gid=$(dscl -plist . -read "/Groups/$group" PrimaryGroupID | xmllint --xpath '//string/text()' - 2> /dev/null)
		fi
		if ! dscl . -read "/Users/$name" > /dev/null 2>&1 ; then
			trace sudo dscl . -create "/Users/$name"
		fi
		_dsclRead() {
			dscl -plist . -read "/Users/$name" "$1" | xmllint --xpath '//string/text()' - 2> /dev/null
		}
		if test "$isHidden" -a "$(_dsclRead AuthenticationAuthority)" ; then
			trace sudo dscl . -delete "/Users/$name" AuthenticationAuthority
		fi
		if test "$isHidden" -a "$(_dsclRead Password)" != '*' ; then
			trace sudo dscl . -create "/Users/$name" Password '*'
		fi
		if test "$(_dsclRead UniqueID)" != "$uid" ; then
			trace sudo dscl . -create "/Users/$name" UniqueID "$uid"
		fi
		if test "$(_dsclRead PrimaryGroupID)" != "$gid" ; then
			trace sudo dscl . -create "/Users/$name" PrimaryGroupID "$gid"
		fi
		if ! dseditgroup -o checkmember -m "$name" "$group" > /dev/null ; then
			trace sudo dseditgroup -o edit -t user -a "$name" "$group"
		fi
		case "$isHidden" in (0) isHidden=NO ;; (1) isHidden=YES ;; esac
		if test "$(_dsclRead IsHidden)" != "$isHidden" ; then
			if test "$isHidden" ; then
				trace sudo dscl . -create "/Users/$name" IsHidden "$isHidden"
			else
				trace sudo dscl . -delete "/Users/$name" IsHidden
			fi
		fi
		if test "$(_dsclRead NFSHomeDirectory)" != "$home" ; then
			trace sudo dscl . -create "/Users/$name" NFSHomeDirectory "$home"
		fi
		if test "$(_dsclRead UserShell)" != "$shell" ; then
			trace sudo dscl . -create "/Users/$name" UserShell "$shell"
		fi
		if test "$(_dsclRead RealName)" != "$description" ; then
			trace sudo dscl . -create "/Users/$name" RealName "$description"
		fi
	fi
	unset name uid gid group isHidden home shell description
}

deleteUser() {
	if $isLinux ; then
		if getent passwd "$1" > /dev/null ; then
			trace sudo deluser "$1"
		fi
	fi
	if $isDarwin ; then
		if dscl . -read "/Users/$1" > /dev/null 2>&1 ; then
			trace sudo dscl . -delete "/Users/$1"
		fi
	fi
}

makeGroup() {
	name= ; gid= ; members= ; description=
	# shellcheck disable=SC1091
	. /dev/stdin  # read named parameters
	if $isLinux ; then
		if ! getent group "$name" > /dev/null ; then
			if test "$gid" ; then
				trace sudo addgroup --gid "$gid" "$name"
			else
				fatalError "Cannot create group $name without a GID"
			fi
		fi
		if test "$gid" && ! getent group "$name" | grep -q "^$name:x:$gid:" ; then
			deleteGroup "$name"
			makeGroup <<- EOF
				name="$name" ; gid="$gid" ; members="$members" ; description="$description"
			EOF
		fi
		echo "$members" | tr ' ' '\n' | while read -r _member && test "$_member" ; do
			if ! getent group "$name" | grep -Fwq "$_member" ; then
				trace sudo usermod --append --groups "$name" "$_member"
			fi
		done
	fi
	if $isDarwin ; then
		if ! dscl . -read "/Groups/$name" > /dev/null 2>&1 ; then
			if test "$gid" ; then
				trace sudo dseditgroup -o create -r "$description" -i "$gid" "$name"
			else
				fatalError "Cannot create group $name without a GID"
			fi
		fi
		_dsclRead() {
			dscl -plist . -read "/Groups/$name" "$1" | xmllint --xpath '//string/text()' - 2> /dev/null
		}
		if test "$gid" -a "$(_dsclRead PrimaryGroupID)" != "$gid" ; then
			trace sudo dseditgroup -o edit -i "$gid" "$name"
		fi
		echo "$members" | tr ' ' '\n' | while read -r _member && test "$_member" ; do
			if ! _dsclRead GroupMembership | grep -Fwq "$_member" ; then
				trace sudo dseditgroup -o edit -t user -a "$_member" "$name"
			fi
		done
		if test "$gid" -a "$(_dsclRead RealName)" != "$description" ; then
			trace sudo dseditgroup -o edit -r "$description" "$name"
		fi
	fi
	unset name gid members description
}

deleteGroup() {
	if $isLinux ; then
		if getent group "$1" > /dev/null ; then
			trace sudo delgroup "$1"
		fi
	fi
	if $isDarwin ; then
		if dscl . -read "/Groups/$1" > /dev/null 2>&1 ; then
			trace sudo dseditgroup -q -o delete "$1"
		fi
	fi
}

# service management

makeService() {
	name= ; label= ; description= ; dependencies= ; lifecycle= ; command= ; environment= ; user= ; group= ; socket= ; socketName= ; socketCompatibility= ; waitForPath=
	# shellcheck disable=SC1091
	. /dev/stdin  # read named parameters
	if $isLinux ; then
		if test "$dependencies" ; then
			_conditionEntries="Requires=$dependencies$newline"
			_conditionEntries="${_conditionEntries}After=$dependencies$newline"
		else
			_conditionEntries=
		fi
		if test "$waitForPath" ; then
			_conditionEntries="${_conditionEntries}RequiresMountsFor=$waitForPath$newline"
		fi
		if test "${socket#/}" != "$socket" ; then
			_conditionEntries="${_conditionEntries}ConditionPathIsReadWrite=${socket%/*}$newline"
		fi
		if test "$lifecycle" = oneshot ; then
			_typeEntry="Type=oneshot$newline"
		else
			_typeEntry=
		fi
		if test "$environment" ; then
			_environmentEntry=Environment=
			# shellcheck disable=SC2329
			_() {
				if test "$1" = "${1#* }" ; then
					_environmentEntry="$_environmentEntry$1 "
				else
					_environmentEntry="$_environmentEntry\"$1\" "
				fi
			}
			forLines "$environment" _
			_environmentEntry="${_environmentEntry% }$newline"
		else
			_environmentEntry=
		fi
		if test "$user" ; then
			_userEntry="User=$user$newline"
		else
			_userEntry=
		fi
		if test "$group" ; then
			_groupEntry="Group=$group$newline"
		else
			_groupEntry=
		fi
		if test "$socket" ; then
			if test "${socket#/}" != "$socket" ; then
				_socketEntry="ListenStream=$socket$newline"
			else
				case "$socket" in
					tcp*) _socketEntry="ListenStream=" ;;
					udp*) _socketEntry="ListenDatagram=" ;;
				esac
				case "$socket" in
					*4://*) _socketEntry="BindIPv6Only=both$newline$_socketEntry" ;;
					*6://*) _socketEntry="BindIPv6Only=ipv6-only$newline$_socketEntry" ;;
				esac
				socket=${socket#*://}
				if test "${socket#\*}" = "$socket" ; then
					_socketEntry="$_socketEntry$socket$newline"
				else
					_socketEntry="$_socketEntry${socket#*:}$newline"
				fi
			fi
			case "$socketCompatibility" in
				inetd-sequential) _socketEntry="${_socketEntry}Accept=no$newline" ;;
				inetd-parallel) _socketEntry="${_socketEntry}Accept=yes$newline" ;;
			esac
			cat > "$name.socket" <<- EOF
				[Unit]
				Description=$description Socket
				Before=multi-user.target
				$_conditionEntries
				[Socket]
				$_socketEntry
				[Install]
				WantedBy=sockets.target
			EOF
			makeFile 644:root:root "/etc/systemd/system/$name.socket" "$name.socket"
			rm "$name.socket"
		fi
		cat > "$name.service" <<- EOF
			[Unit]
			Description=$description
			$_conditionEntries
			[Service]
			${_userEntry}${_groupEntry}StandardOutput=null
			StandardError=null
			${_typeEntry}${_environmentEntry}ExecStart=$command

			[Install]
			WantedBy=multi-user.target
		EOF
		makeFile 644:root:root "/etc/systemd/system/$name.service" "$name.service"
		rm "$name.service"
		if didCreate ; then
			trace sudo systemctl daemon-reload
			if test "$socket" ; then
				trace sudo systemctl enable --now "$name.socket"
			else
				trace sudo systemctl enable --now "$name.service"
			fi
		elif didModify ; then
			trace sudo systemctl daemon-reload
			restartService "$name"
		fi
	fi
	if $isDarwin ; then
		if test "$waitForPath" ; then
			_commandEntry="\"ProgramArguments\": [\"/bin/sh\",\"-c\",\"/bin/wait4path $waitForPath && exec $command\"],"
		else
			_commandEntry='"ProgramArguments": ['
			for _part in $command ; do _commandEntry=$_commandEntry\"$_part\", ; done
			_commandEntry="$_commandEntry],"
		fi
		if test "$environment" ; then
			_environmentEntry='"EnvironmentVariables": {'
			# shellcheck disable=SC2329
			_() { _environmentEntry="$_environmentEntry\"${1%%=*}\":\"${1#*=}\"," ; }
			forLines "$environment" _
			_environmentEntry="$_environmentEntry},"
		else
			_environmentEntry=
		fi
		if test "$user" ; then
			_userEntry="\"UserName\": \"$user\","
		else
			_userEntry=
		fi
		if test "$group" ; then
			_groupEntry="\"GroupName\": \"$group\","
		else
			_groupEntry=
		fi
		case "$lifecycle" in
			daemon) _lifecycleEntry='"RunAtLoad": true, "KeepAlive": true,' ;;
			oneshot) _lifecycleEntry='"RunAtLoad": true,' ;;
			demand) _lifecycleEntry='"EnablePressuredExit": true,' ;;
			*) fatalError "Unsupported service lifecycle value $lifecycle" ;;
		esac
		if test "$socket" ; then
			socketName=${socketName:-$name}
			_socketEntry="\"Sockets\": { \"$socketName\": {"
			if test "${socket#/}" != "$socket" ; then
				_socketEntry="$_socketEntry\"SockFamily\":\"Unix\",\"SockPathName\":\"$socket\""
			else
				case "$socket" in
					tcp*) _socketEntry="$_socketEntry\"SockProtocol\":\"TCP\"," ;;
					udp*) _socketEntry="$_socketEntry\"SockProtocol\":\"UDP\"," ;;
				esac
				case "$socket" in
					*4://*) _socketEntry="$_socketEntry\"SockFamily\":\"IPv4\"," ;;
					*6://*) _socketEntry="$_socketEntry\"SockFamily\":\"IPv6\"," ;;
				esac
				socket=${socket#*://}
				if test "${socket#\*}" = "$socket" ; then
					_socketEntry="$_socketEntry\"SockNodeName\":\"${socket%:*}\","
				fi
				_socketEntry="$_socketEntry\"SockServiceName\":\"${socket#*:}\","
			fi
			_socketEntry="$_socketEntry}},"
			case "$socketCompatibility" in
				inetd-sequential) _socketEntry="$_socketEntry\"inetdCompatibility\": { \"Wait\":true }," ;;
				inetd-parallel) _socketEntry="$_socketEntry\"inetdCompatibility\": { \"Wait\":false }," ;;
			esac
		else
			_socketEntry=
		fi
		plutil -convert xml1 -o "$label.plist" - <<- EOF
			{
				"Label": "$label",
				$_commandEntry
				$_environmentEntry
				$_userEntry
				$_groupEntry
				$_lifecycleEntry
				$_socketEntry
				"StandardErrorPath": "/dev/null",
				"StandardOutPath": "/dev/null"
			}
		EOF
		makeFile 644:root:wheel "/Library/LaunchDaemons/$label.plist" "$label.plist"
		rm "$label.plist"
		if didCreate ; then
			trace sudo launchctl bootstrap system "/Library/LaunchDaemons/$label.plist"
		elif didModify ; then
			restartService "$name"
		fi
	fi
	unset name label description dependencies lifecycle command environment user group socket socketName socketCompatibility waitForPath
}

deleteService() {
	if $isLinux ; then
		if systemctl list-unit-files "$1.socket" > /dev/null 2>&1 ; then
			trace sudo systemctl disable --now "$1.socket"
		fi
		if systemctl list-unit-files "$1.service" > /dev/null 2>&1 ; then
			trace sudo systemctl disable --now "$1.service"
		fi
		deleteFile "/etc/systemd/system/$1.socket" "/etc/systemd/system/$1.service"
		if didRemove ; then
			trace sudo systemctl daemon-reload
		fi
	fi
	if $isDarwin ; then
		# translate the service name to a launchd reverse DNS service label
		_label=$(launchctl print system | grep -Fw "$1" | cut -f4)
		if test "$_label" ; then
			trace sudo launchctl bootout "system/$_label"
		fi
		deleteFile "/Library/LaunchDaemons/$_label.plist"
	fi
}

restartService() {
	if $isLinux ; then
		if systemctl list-unit-files "$1.service" > /dev/null 2>&1 ; then
			trace sudo systemctl restart "$1.service"
		fi
	fi
	if $isDarwin ; then
		# translate the service name to a launchd reverse DNS service label
		_label=$(launchctl print system | grep -w "$1\$" | cut -f4)
		if test "$_label" ; then
			trace sudo launchctl kill TERM "system/$_label" || true
		fi
	fi
}

# settings in preference files

makePref() {
	if $isDarwin ; then
		_file=$1
		_key=$2
		_type=$3
		shift ; shift ; shift

		if test -w "${_file%/*}" -a -w "$_file" ; then
			_sudo=
		else
			_sudo=sudo
		fi

		_getPref() { defaults read "${_file%.plist}" "$_key" 2> /dev/null ; }
		_setPref() { trace $_sudo defaults write "${_file%.plist}" "$_key" "-$_type" "$@" ; }

		case "$_type" in
			string|int|float)
				if test "$(_getPref || true)" != "$1" ; then _setPref "$1" ; fi ;;
			bool)
				if test "$(_getPref || true)" != "$(case "$1" in (true) echo 1 ;; (false) echo 0 ;; esac)" ; then _setPref "$1" ; fi ;;
			array)
				_expected=$(printf '(' ; for _value ; do test "$_value" = "$1" || printf , ; printf '\n    "%s"' "$_value" ; done ; printf '\n)\n')
				if test "$(_getPref || true)" != "$_expected" ; then _setPref "$@" ; fi ;;
			array-add)
				if ! _getPref | grep -Fqw "$1" ; then _setPref "$1" ; fi ;;
			delete)
				if _getPref > /dev/null ; then trace $_sudo defaults delete "${_file%.plist}" "$_key" ; fi ;;
			*)
				fatalError "Unsupported preference type $_type"
		esac
	else
		fatalError 'No preference file support on Linux'
	fi
}

# package installation

installPackage() {
	_pkg=$1
	_choice=$2

	# assumes that the package file lives in the Nix store
	_name=${_pkg##*/}
	_name=${_name#*-}
	_name=${_name%%-*}.pkg

	ln -s "$_pkg" "$_name"
	checkSig "$_name"
	if test "$_choice" ; then
		trace sudo installer -pkg "$_name" -target LocalSystem -applyChoiceChangesXML "$_choice"
	else
		trace sudo installer -pkg "$_name" -target LocalSystem
	fi
	rm "$_name"
}

# interactive script editing

interactiveCommands() {
	if test -t 3 -a -t 4 ; then
		if read -r first ; then
			{
				if test "$2" ; then echo "# $2" ; fi
				if test "$3" ; then echo "# $3" ; fi
				if test "$4" ; then echo "# $4" ; fi
				echo "$first"
				cat
			} > "$1.sh"
			# shellcheck disable=SC2086
			eval ${EDITOR:-vi} "$1.sh" <&3 >&4
			trace sudo sh "$1.sh" <&3 >&4
			rm "$1.sh"
		fi
	else
		# consume input to not cause upstream SIGPIPE termination
		cat > /dev/null
	fi
}

interactiveDeletes() {
	if read -r first ; then
		{
			echo "$first"
			cat
		} | sort | sed "s/'/'\"'\"'/ ; s/^/rm -rf '/ ; s/$/'/" | \
			interactiveCommands "$1" "$2" 'Files will be deleted unless lines are commented or removed.'
	fi
}
