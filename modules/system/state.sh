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

	if ! test -f "$_target" || ! cmp --quiet "$_source" "$_target" ; then
		# shellcheck disable=SC2086
		trace $_sudo cp -a "$_source" "$_target"
	fi
	_setPermissions "$_target"
}

# user and group management

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
