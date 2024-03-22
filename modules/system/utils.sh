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

# colored output

if test "$(tput colors)" -ge 16 ; then
	if test -t 1 ; then _hasColorStdout=true ; else _hasColorStdout=false ; fi
	if test -t 2 ; then _hasColorStderr=true ; else _hasColorStderr=false ; fi
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
		echo "$_headingColor$_heading$_resetStdout"
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
