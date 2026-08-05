#!/usr/bin/env bash
set -euo pipefail

# Bash Common Definitions (common.sh)
# Copyright (c) 2026, Leander Seidlitz

LOG_HNAME="$(hostname)"

eprint(){
	[[ -n "${LOGFILE:-}" ]] && echo "    $*" >> "$LOGFILE"
	[[ -n "${QUIET:-}" ]] && return
	echo "       [1;90m[${LOG_HNAME}] $*[m" >&2
}

elog() {
	[[ -n "${LOGFILE:-}" ]] && echo "LOG: $*" >> "$LOGFILE"
	[[ -n "${QUIET:-}" ]] && return
	echo "    [[1m+[m][1;90m[${LOG_HNAME}] $*[m" >&2
}

edebug() {
	[[ -n "${LOGFILE:-}" ]] && echo "DEBUG: $*" >> "$LOGFILE"
	[[ -n "${QUIET:-}" ]] && return
	echo "    [[1;90m+[m][1;90m[${LOG_HNAME}] $*[m" >&2
}

einfo() {
	[[ -n "${LOGFILE:-}" ]] && echo "INFO: $*" >> "$LOGFILE"
	[[ -n "${QUIET:-}" ]] && return
	echo "    [[1;32m+[m][1;90m[${LOG_HNAME}] $*[m" >&2
}

eattention() {
	[[ -n "${LOGFILE:-}" ]] && echo "ATTENTION: $*" >> "$LOGFILE"
	[[ -n "${QUIET:-}" ]] && return
	echo "    [[1;33m![m][1;33m[${LOG_HNAME}] $*[m" >&2
}

ewarn() {
	[[ -n "${LOGFILE:-}" ]] && echo "WARNING: $*" >> "$LOGFILE"
	echo "    [[1;33m+[m][1;33m[${LOG_HNAME}] $*[m" >&2
}

eerror() {
	[[ -n "${LOGFILE:-}" ]] && echo "ERROR: $*" >> "$LOGFILE"
	echo "   [1;31m* ERROR[m[1;90m[${LOG_HNAME}]: $*[m" >&2
}


die() {
	[[ -n "${LOGFILE:-}" ]] && echo "ERROR, FATAL: $*" >> "$LOGFILE"
	eerror "$*"
	export DIED_ERROR="yes"
	exit 1
}

begin(){
        [[ -n "${QUIET:-}" ]] && return
	echo "[1;36m[[1;32mbegin[1;36m][${LOG_HNAME}] $*[m" >&2
}

ok(){
        [[ -n "${QUIET:-}" ]] && return
	echo "[1;36m[[1;32m   ok[1;36m][${LOG_HNAME}] $*[m" >&2
}

countdown() {
        echo -n "$2" >&2

        local i="$1"
        while [[ $i -gt 0 ]]; do
		echo -n " [1;31m$i[m" >&2
                i=$((i - 1))
                sleep 1
        done
        echo >&2
}
