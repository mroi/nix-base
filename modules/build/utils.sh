# command line arguments

_argv=$*

checkArgs() {
	for _arg1 in $_argv ; do
		for _arg2 in "$@" ; do
			test "$_arg1" = "$_arg2" && return 0
		done
	done
	return 1
}

# help printing mode

if checkArgs --help -h ; then
	if test -z "$_helpCommandsPrinted" ; then
		echo "Usage: ${0##*/} [ <commands> ]"
		echo
		# shellcheck disable=SC2154
		if command -v nix > /dev/null && test "$self" -a "$machine"; then
			echo "Default commands for this machine:"
			nix eval --quiet --no-warn-dirty --apply toString --raw \
				"${self}#baseConfigurations.${machine}.config.system.defaultCommands"
			echo
		fi
		echo
		echo "Available commands are:"
		echo
	fi

	checkArgs() {
		# collect and print all commands checked with checkArgs
		_toPrint=
		for _arg in "$@" ; do
			if ! hasLine "$_helpCommandsPrinted" "$_arg" ; then
				_toPrint="$_toPrint$_arg$newline"
			fi
		done
		# print commands ordered by their length to illustrate hierarchy
		printf %s "$_toPrint" | awk 'BEGIN { OFS="\t" }; { print length(), $0 }' | sort -n | cut -f2
		_helpCommandsPrinted="$_helpCommandsPrinted$_toPrint$newline"
		# return false from checkArgs to prevent actual command execution
		return 1
	}
fi

# tools for of multi-line variable content

newline='
'

_ifsPrevious=$IFS
_ifsLines=$(printf '\n\t')

forLines() {
	IFS=$_ifsLines
	for _line in $1 ; do
		"$2" "$_line"
	done
	IFS=$_ifsPrevious
}
hasLine() {
	_needle="$2"
	_found=false
	_() { if test "$1" = "$_needle" ; then _found=true ; fi ; }
	forLines "$1" _
	if $_found ; then return 0 ; else return 1 ; fi
}

# colored output

if tput colors > /dev/null 2>&1 && test "$(tput colors)" -ge 16 ; then
	if test -t 1 ; then _hasColorStdout=true ; else _hasColorStdout=false ; fi
	if test -t 2 ; then _hasColorStderr=true ; else _hasColorStderr=false ; fi
else
	_hasColorStdout=false
	_hasColorStderr=false
fi

_headingColor=$(if $_hasColorStdout ; then tput bold ; fi)
_underline=$(if $_hasColorStdout ; then tput smul ; fi)
_errorColor=$(if $_hasColorStderr ; then tput setaf 9 ; tput bold ; fi)
_warningColor=$(if $_hasColorStderr ; then tput setaf 11 ; tput bold ; fi)
_traceColor=$(if $_hasColorStdout ; then tput dim || printf "\033[2m" ; fi)
_sudoColor=$(if $_hasColorStdout ; then tput setaf 5 ; fi)
_resetStdout=$(if $_hasColorStdout ; then tput sgr0 ; fi)
_resetStderr=$(if $_hasColorStderr ; then tput sgr0 ; fi)

storeHeading() {
	# heading will only be printed if any other output is generated
	_heading=$*
}
flushHeading() {
	# actually print heading
	if test "$_heading" ; then
		echo
		if test "$_heading" != - ; then
			echo "$_headingColor$_heading$_resetStdout"
		fi
		unset _heading
	fi
}
printSubheading() {
	flushHeading
	echo "$_underline$*$_resetStdout"
}
printError() {
	flushHeading
	echo "$_errorColor$*$_resetStderr" >&2
}
printWarning() {
	flushHeading
	echo "$_warningColor$*$_resetStderr" >&2
}
printInfo() {
	flushHeading
	echo "$*" >&2
}
printDiff() {
	# print a diff if it is small (50 lines)
	if test -r "$1" -a -r "$2" ; then
		_length=$(diff -u "$1" "$2" 2> /dev/null | sed 51q | wc -l)
		if test "$_length" -gt 3 -a "$_length" -lt 51 ; then
			flushHeading
			diff -u --color=auto "$1" "$2" || true
		fi
	fi
}
trace() {
	flushHeading
	if test "$1" = sudo ; then
		shift
		printf %s "$_traceColor>$_resetStdout$_sudoColor sudo$_resetStdout $_traceColor$*$_resetStdout"
		if checkArgs --interactive -i ; then read -r _ < /dev/tty ; else echo ; fi
		sudo "$@"
	else
		printf %s "$_traceColor> $*$_resetStdout"
		if checkArgs --interactive -i ; then read -r _ < /dev/tty ; else echo ; fi
		"$@"
	fi
}
fatalError() {
	printError "$@"
	exit 69  # EX_UNAVAILABLE
}

highlightOutput() {
	if $_hasColorStdout ; then
		sed "$1
			s/^%UNDERLINE%/$(tput smul)/
			s/%NOUNDERLINE%\$/$(tput rmul)/
			s/^%GREEN%/$(tput setaf 2)/
			s/^%YELLOW%/$(tput setaf 11)/
			s/^%RED%/$(tput setaf 9)/
			s/%NORMAL%\$/$(tput sgr0)/
		"
	else
		cat
	fi
}

# system recognition

isLinux=${isLinux:-$(case "$(uname)" in (Linux) echo true ;; (*) echo false ;; esac)}
isDarwin=${isDarwin:-$(case "$(uname)" in (Darwin) echo true ;; (*) echo false ;; esac)}
isx86_64=${isx86_64:-$(case "$(uname -m)" in (x86_64) echo true ;; (*) echo false ;; esac)}
isAarch64=${isAarch64:-$(case "$(uname -m)" in (aarch64|arm64) echo true ;; (*) echo false ;; esac )}

if ! test "${isLinux#false}${isDarwin#false}" = true ; then
	fatalError 'Exactly one of isLinux, isDarwin must be true'
fi
if ! test "${isx86_64#false}${isAarch64#false}" = true ; then
	fatalError 'Exactly one of isx86_64, isAarch64 must be true'
fi

# transition to temporary directory

cdTemporaryDirectory() {
	if test -d /nix/var/tmp ; then
		_tmpdir=/nix/var/tmp
	else
		_tmpdir=${TMPDIR%/}
	fi
	_tmpdir=$(mktemp --directory --tmpdir="$_tmpdir" -t "rebuild$($isDarwin || echo .XXXXXXXX)")
	# shellcheck disable=SC2064
	trap "rm -rf \"$_tmpdir\"" EXIT HUP TERM QUIT
	# shellcheck disable=SC2064
	trap "rm -rf \"$_tmpdir\" ; exit 75  # EX_TEMPFAIL" INT
	cd "$_tmpdir"
}

# code signature check

checkSig() {
	if $isLinux ; then fatalError 'code signatures not supported on Linux' ; fi

	_path=$1
	_team=$2

	case "$_path" in
	*.app|*.dmg)
		if ! codesign --verify "$_path" -R='anchor trusted' --strict=symlinks --deep ; then
			printWarning "Code signature invalid for $_path"
			return 1
		fi
		if test "$_team" && ! codesign --display --verbose "$_path" 2>&1 | grep -Fqx "TeamIdentifier=$_team" ; then
			printWarning "Unexpected team identifier in signature at $_path"
			printInfo "expected: $_team"
			return 1
		fi ;;
	*.pkg)
		if ! pkgutil --check-signature "$_path" > /dev/null ; then
			printWarning "Package signature invalid for $_path"
			return 1
		fi
		if test "$_team" && ! pkgutil --check-signature "$_path" | grep -Fq "($_team)" ; then
			printWarning "Unexpected team identifier in signature at $_path"
			printInfo "expected: $_team"
			return 1
		fi ;;
	esac
}

# ensure the Nix command is runnable

if $isLinux ; then _sslCertFile=/etc/ssl/certs/ca-certificates.crt ; fi
if $isDarwin ; then _sslCertFile=/etc/ssl/cert.pem ; fi

if ! command -v nix > /dev/null ; then
	nix() {
		if test -x "${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile/bin/nix" ; then
			NIX_CONF_DIR=/nix NIX_SSL_CERT_FILE=$_sslCertFile "${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile/bin/nix" "$@"
		elif test -x "${_nixExe:=$(find /nix/store/*-nix-*/bin/nix 2> /dev/null | sort --field-separator=- --key=3 --version-sort | tail -n1)}" ; then
			NIX_CONF_DIR=/nix NIX_SSL_CERT_FILE=$_sslCertFile "$_nixExe" "$@"
		else
			false
		fi
	}
fi
