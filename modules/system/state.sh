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
			test -z "$_perms" || test "$(stat -c %a "$1")" = "$_perms" || trace $_sudo chmod "$_perms" "$1"
			test -z "$_owner" || test "$(stat -c %U "$1")" = "$_owner" || trace $_sudo chown "$_owner" "$1"
			test -z "$_group" || test "$(stat -c %G "$1")" = "$_group" || trace $_sudo chgrp "$_group" "$1"
		fi
	fi
	# shellcheck disable=SC2086
	if $isDarwin ; then
		if test "$_statFormatDarwin" && test "$(stat -f "$_statFormatDarwin" "$1")" != "$_statExpected" ; then
			test -z "$_perms" || test "$(stat -f %Mp%Lp "$1")" -eq "$_perms" || trace $_sudo chmod "$_perms" "$1"
			test -z "$_owner" || test "$(stat -f %Su "$1")" = "$_owner" || trace $_sudo chown "$_owner" "$1"
			test -z "$_group" || test "$(stat -f %Sg "$1")" = "$_group" || trace $_sudo chgrp "$_group" "$1"
			test -z "$_flags" || test "$(stat -f %Sf "$1")" = "$_flags" || trace $_sudo chflags "$_flags" "$1"
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
		# shellcheck disable=SC2086
		test -d "$_dir" || trace $_sudo mkdir "$_dir"
		_setPermissions "$_dir"
	done
}

updateFile() {
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
		# print a diff if it is small (50 lines)
		if test -r "$_target" -a -r "$_source" ; then
			_length=$(diff -u "$_target" "$_source" 2> /dev/null | sed 51q | wc -l)
			if test "$_length" -gt 3 -a "$_length" -lt 51 ; then
				flushHeading
				diff -u --color=auto "$_target" "$_source" || true
			fi
		fi
		if ! test -f "$_target" ; then
			_update=created
		else
			_update=modified
		fi
		# shellcheck disable=SC2086
		trace $_sudo cp -a "$_source" "$_target"
	fi
	if ! test -f "$_target" && ! test "$_source" ; then
		trace $_sudo touch "$_target"
		_update=created
	fi
	_setPermissions "$_target"
}

updateDidCreate() {
	if test "$_update" = created ; then return 0 ; else return 1 ; fi
}

updateDidModify() {
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

deleteDidRemove() {
	if "$_deleted" ; then return 0 ; else return 1 ; fi
}

# user and group management

createUser() {
	name= ; uid= ; gid= ; group= ; isHidden= ; home= ; shell= ; description=
	# shellcheck disable=SC1091
	. /dev/stdin  # read named parameters
	if $isLinux ; then
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
			createUser < /dev/null
		fi
	fi
	if $isDarwin ; then
		if ! dscl . -read "/Users/$name" > /dev/null 2>&1 ; then
			trace sudo dscl . -create "/Users/$name"
		fi
		_dsclRead() {
			dscl -plist . -read "/Users/$name" "$1" | xmllint --xpath '//string/text()' - 2> /dev/null
		}
		if test "$(_dsclRead AuthenticationAuthority)" ; then
			trace sudo dscl . -delete "/Users/$name" AuthenticationAuthority
		fi
		if test "$(_dsclRead Password)" != '*' ; then
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
		if test "$(_dsclRead IsHidden)" != "${isHidden:-0}" ; then
			trace sudo dscl . -create "/Users/$name" IsHidden "${isHidden:-0}"
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

createGroup() {
	name= ; gid= ; members= ; description=
	# shellcheck disable=SC1091
	. /dev/stdin  # read named parameters
	if $isLinux ; then
		if ! getent group "$name" > /dev/null ; then
			trace sudo addgroup --gid "$gid" "$name"
		fi
		if ! getent group "$name" | grep -q "^$name:x:$gid:" ; then
			deleteGroup "$name"
			createGroup < /dev/null
		fi
		echo "$members" | tr ' ' '\n' | while read -r _member && test "$_member" ; do
			if ! getent group "$name" | grep -Fwq "$_member" ; then
				trace sudo usermod --append --groups "$name" "$_member"
			fi
		done
	fi
	if $isDarwin ; then
		if ! dscl . -read "/Groups/$name" > /dev/null 2>&1 ; then
			trace sudo dseditgroup -o create -r "$description" -i "$gid" "$name"
		fi
		_dsclRead() {
			dscl -plist . -read "/Groups/$name" "$1" | xmllint --xpath '//string/text()' - 2> /dev/null
		}
		if test "$(_dsclRead PrimaryGroupID)" != "$gid" ; then
			trace sudo dseditgroup -o edit -i "$gid" "$name"
		fi
		echo "$members" | tr ' ' '\n' | while read -r _member && test "$_member" ; do
			if ! _dsclRead GroupMembership | grep -Fwq "$_member" ; then
				trace sudo dseditgroup -o edit -t user -a "$_member" "$name"
			fi
		done
		if test "$(_dsclRead RealName)" != "$description" ; then
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

createService() {
	name= ; label= ; description= ; command= ; environment= ; group= ; socket= ; waitForPath=
	# shellcheck disable=SC1091
	. /dev/stdin  # read named parameters
	if $isLinux ; then
		if test "$waitForPath" ; then
			_conditionEntries="RequiresMountsFor=$waitForPath
"
		else
			_conditionEntries=
		fi
		if test "$socket" ; then
			_conditionEntries="${_conditionEntries}ConditionPathIsReadWrite=${socket%/*}
"
		fi
		if test "$environment" ; then
			_environmentEntry=Environment=
			IFS=$(printf '\n\t')
			for _line in $environment ; do
				_environmentEntry="$_environmentEntry\"${_line}\" "
			done
			IFS=$(printf ' \n\t')
			_environmentEntry="${_environmentEntry% }
"
		else
			_environmentEntry=
		fi
		if test "$group" ; then
			_groupEntry="Group=$group
"
		else
			_groupEntry=
		fi
		if test "$socket" ; then
			cat > "$name.socket" <<- EOF
				[Unit]
				Description=$description Socket
				Before=multi-user.target
				$_conditionEntries
				[Socket]
				ListenStream=$socket

				[Install]
				WantedBy=sockets.target
			EOF
			updateFile 644:root:root "/etc/systemd/system/$name.socket" "$name.socket"
			rm "$name.socket"
		fi
		cat > "$name.service" <<- EOF
			[Unit]
			Description=$description
			$_conditionEntries
			[Service]
			${_groupEntry}StandardOutput=null
			StandardError=null
			${_environmentEntry}ExecStart=$command
			KillMode=process
		EOF
		updateFile 644:root:root "/etc/systemd/system/$name.service" "$name.service"
		rm "$name.service"
		if updateDidCreate ; then
			trace sudo systemctl daemon-reload
			if test "$socket" ; then
				trace sudo systemctl enable "$name.socket"
				trace sudo systemctl start "$name.socket"
			else
				trace sudo systemctl enable "$name.service"
				trace sudo systemctl start "$name.service"
			fi
		elif updateDidModify ; then
			trace sudo systemctl daemon-reload
			restartService "$name"
		fi
	fi
	if $isDarwin ; then
		if test "$waitForPath" ; then
			_commandEntry="\"ProgramArguments\": [\"/bin/sh\",\"-c\",\"/bin/wait4path $waitForPath && exec $command\"],"
		else
			_commandEntry="\"ProgramArguments\": ["
			for _part in $command ; do _commandEntry=$_commandEntry\"$_part\", ; done
			_commandEntry="$_commandEntry],"
		fi
		if test "$environment" ; then
			_environmentEntry="\"EnvironmentVariables\": {"
			IFS=$(printf '\n\t')
			for _line in $environment ; do
				_environmentEntry="$_environmentEntry\"${_line%%=*}\":\"${_line#*=}\","
			done
			IFS=$(printf ' \n\t')
			_environmentEntry="$_environmentEntry},"
		else
			_environmentEntry=
		fi
		if test "$group" ; then
			_groupEntry="\"GroupName\": \"$group\","
		else
			_groupEntry=
		fi
		plutil -convert xml1 -o "$label.plist" - <<- EOF
			{
				$_environmentEntry
				$_groupEntry
				"KeepAlive": true,
				"Label": "$label",
				$_commandEntry
				"RunAtLoad": true,
				"StandardErrorPath": "/dev/null",
				"StandardOutPath": "/dev/null"
			}
		EOF
		updateFile 644:root:wheel "/Library/LaunchDaemons/$label.plist" "$label.plist"
		rm "$label.plist"
		if updateDidCreate ; then
			trace sudo launchctl bootstrap system "/Library/LaunchDaemons/$label.plist"
		elif updateDidModify ; then
			restartService "$name"
		fi
	fi
	unset name label description command environment group socket waitForPath
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
		if deleteDidRemove ; then
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
		_label=$(launchctl print system | grep -Fw "$1" | cut -f4)
		if test "$_label" ; then
			trace sudo launchctl kill TERM "system/$_label"
		fi
	fi
}
