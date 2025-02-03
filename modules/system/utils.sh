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

# tools for of multi-line variable content

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
trace() {
	flushHeading
	if test "$1" = sudo ; then
		shift
		echo "$_traceColor>$_resetStdout$_sudoColor sudo$_resetStdout $_traceColor$*$_resetStdout"
		sudo "$@"
	else
		echo "$_traceColor> $*$_resetStdout"
		"$@"
	fi
}
fatalError() {
	printError "$@"
	exit 69  # EX_UNAVAILABLE
}

# system recognition

isLinux=${isLinux:-$(case "$(uname)" in (Linux) echo true ;; (*) echo false ;; esac)}
isDarwin=${isDarwin:-$(case "$(uname)" in (Darwin) echo true ;; (*) echo false ;; esac)}
isx86_64=${isx86_64:-$(case "$(uname -m)" in (x86_64) echo true ;; (*) echo false ;; esac)}
isAarch64=${isAarch64:-$(case "$(uname -m)" in (aarch64|arm64) echo true ;; (*) echo false ;; esac )}

if ! test "${isLinux#false}${isDarwin#false}" = true ; then
	fatalError 'Exactly one of isLinux, isDarwin must be true.'
fi
if ! test "${isx86_64#false}${isAarch64#false}" = true ; then
	fatalError 'Exactly one of isx86_64, isAarch64 must be true.'
fi
