#!/bin/bash

#Absolute path to this script
SCRIPT=$(readlink -f "$0")
#Absolute path this script is in
SCRIPTPATH=$(dirname "$SCRIPT")

CWD="$PWD"
projectDir="$PWD"
sourceDir="$SCRIPTPATH/../luarocks/lua_modules/lib/luarocks/rocks-5.5/lanes/src"

set -o pipefail

while read -r line; do
    case "${line%% *}" in
        CYGWIN* | MINGW* | MSYS* )
            LUAROCKS_SUFFIX=.bat
            # export CFLAGS="/std:c++20 /EHsc"
            ;;

        *)
            LUAROCKS_SUFFIX=
            # export CFLAGS="-std=c++2a"
            # export LDFLAGS="-lm -lstdc++"
            # export CC="g++"
            ;;
    esac
    break
done < /proc/version

if command -v cygpath &>/dev/null; then

function luarocks_cmd() {
    source "${projectDir}/scripts/vcvars_restore_start.sh"
    local _PATH="$PATH"
    source "${projectDir}/scripts/vcvars_restore_end.sh"

    PATH="$_PATH" ./luarocks/luarocks${LUAROCKS_SUFFIX} "$@"
}

else

function luarocks_cmd() {
    ./luarocks/luarocks${LUAROCKS_SUFFIX} "$@"
}

fi

function install_lanes() {
    local rock_installed="$(luarocks_cmd list --porcelain lanes)"

    if [ ${#rock_installed} -ne 0 ]; then
        luarocks_cmd remove lanes
    fi

    rm -rf "$sourceDir"
    git clone -b v3.17.2 "https://github.com/LuaLanes/lanes.git" "$sourceDir" && \
    cd "$sourceDir" || return $?

    local BRANCH=3.x
    local SOURCE_DIR="$PWD"
    if command -v cygpath &>/dev/null; then
        SOURCE_DIR="$(cygpath -m "$sourceDir")"
    fi

    git checkout -b "$BRANCH" && \
    git apply "$SCRIPTPATH/patches/001-lanes-src.patch" && \
    sed -e "s#@BRANCH@#$BRANCH#" -e "s#@SOURCE_DIR@#$SOURCE_DIR#" -i lanes-3.17.2-1.rockspec && \
    git add . && \
    git commit -m "Fix lua 5.5 compilation" && \
    cd "$CWD" && \
    luarocks_cmd install "$sourceDir/lanes-3.17.2-1.rockspec"

    # luarocks_cmd install 'https://raw.githubusercontent.com/LuaLanes/lanes/refs/tags/v4.0.0/lanes-4.0.0-0.rockspec' --force
}

install_lanes
