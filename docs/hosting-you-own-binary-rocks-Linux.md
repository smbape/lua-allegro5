# Hosting you own binary rocks on Linux

## Table Of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Prerequisites](#prerequisites)
  - [[Ubuntu, Debian] Install needed packages:](#ubuntu-debian-install-needed-packages)
  - [[Fedora] Install needed packages:](#fedora-install-needed-packages)
  - [[Almalinux 8] Install needed packages:](#almalinux-8-install-needed-packages)
  - [[Almalinux 9, 10] Install needed packages:](#almalinux-9-10-install-needed-packages)
- [Build System Environment](#build-system-environment)
- [Download the source code](#download-the-source-code)
- [Build](#build)
- [Testing our custom prebuilt binary](#testing-our-custom-prebuilt-binary)
  - [Prepare](#prepare)
  - [Initialize our test project and install our custom prebuilt binary](#initialize-our-test-project-and-install-our-custom-prebuilt-binary)
  - [Test](#test)
- [Hosting on a web server](#hosting-on-a-web-server)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

Here we will build a custom allegro5 with the folling modifications:
  - Enable unstable API

The procedure has been tested on :
  - [Ubuntu 24.04 (Jammy Jellyfish)](https://releases.ubuntu.com/jammy/)

## Prerequisites

  - Install [CMake >= 3.25](https://cmake.org/download/)
  - Install [LuaRocks](https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Unix)
  - Install [Ninja](https://ninja-build.org/)
  - Install [NodeJS](https://nodejs.org/en/download/current)
  - Install [vcpkg](https://learn.microsoft.com/en-us/vcpkg/get_started/get-started?pivots=shell-bash)

### [Ubuntu, Debian] Install needed packages:
```sh
sudo apt install -y \
    autoconf autoconf-archive automake libtool \
    build-essential curl git libgl-dev libglx-dev libegl-dev libgles-dev libglu1-mesa-dev libreadline-dev \
    libxcursor-dev patchelf pkg-config python3-pip python3-venv unzip wget zip \
    libflac-dev libfreeimage-dev libfreetype-dev libharfbuzz-dev libogg-dev \
    libopenal-dev libopenmpt-dev libphysfs-dev \
    libtheora-dev libvorbis-dev libwebp-dev
```

### [Fedora] Install needed packages:
```sh
sudo dnf install -y \
    autoconf autoconf-archive automake libtool \
    curl git make readline-devel libXcursor-devel patch pkg-config unzip wget zip \
    flac-devel freeimage-devel freetype-devel harfbuzz-devel libopenmpt-devel libtheora-devel \
    libvorbis-devel libwebp-devel openal-soft-devel physfs-devel turbojpeg-devel \
    gcc gcc-c++ patchelf python3-pip
```

### [Almalinux 8] Install needed packages:
```sh
sudo dnf install -y \
    autoconf autoconf-archive automake libtool \
    curl git make readline-devel libXcursor-devel patch pkg-config unzip wget zip \
    flac-devel freeimage-devel freetype-devel harfbuzz-devel libopenmpt-devel libtheora-devel \
    libvorbis-devel libwebp-devel openal-soft-devel physfs-devel turbojpeg-devel && \
sudo config-manager --set-enabled powertools && \
sudo dnf install -y almalinux-release-devel epel-release && \
sudo dnf install -y https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm
sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm && \
sudo dnf update -y && \
sudo dnf install -y gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ patchelf python3.12-pip && \
source /opt/rh/gcc-toolset-12/enable
```

### [Almalinux 9, 10] Install needed packages:
```sh
sudo dnf install -y curl gcc gcc-c++ git \
        libjpeg-devel libpng-devel readline-devel make patch tbb-devel \
        patchelf pkg-config python3-pip qt5-qtbase-devel unzip wget zip && \
sudo config-manager --set-enabled crb && \
sudo dnf install -y almalinux-release-devel epel-release && \
sudo dnf install -y https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-9.noarch.rpm
sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-9.noarch.rpm && \
sudo dnf update -y && \
sudo dnf install -y gcc gcc-c++ patchelf python3-pip
```

## Build System Environment

We will name our LuaRocks pakcage **allegro5_lua-custom** in order to avoid conflict with the original package name

In this example, we will use the following directories: 
  - The **Lua binary directory** is _/io/luarocks-binaries-custom/lua-allegro5/out/prepublish/build/allegro5_lua-custom//out/install/Linux-GCC-Release/bin_
  - The **LuaRocks binary directory** is _/io/luarocks-binaries-custom/lua-allegro5/out/prepublish/build/allegro5_lua-custom/out/build.luaonly/Linux-GCC-Release/luarocks/luarocks-prefix/src/luarocks-build/bin_
  - The **build directory** is _/io/luarocks-binaries-custom/build_
  - The **server directory** is _/io/luarocks-binaries-custom/server_
  - The **test directory** is _/io/luarocks-binaries-custom/test/lua-allegro5_

## Download the source code

```sh
git clone --depth 1 --branch v0.0.1 https://github.com/smbape/lua-allegro5.git /io/luarocks-binaries-custom/build && \
cd /io/luarocks-binaries-custom/build && \
npm ci
```

## Build

```sh
# --lua-versions luajit-2.1,5.1,5.2,5.3,5.4,5.5
node scripts/prepublish.js --pack --server=/io/luarocks-binaries-custom/server --lua-versions luajit-2.1 --name=allegro5_lua-custom \
    -DENABLE_REPAIR=ON \
    -DAUDITWHEEL_exclude="libGL*;libEGL*" \
    -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
    -DWANT_UNSTABLE=ON
```

  - `-DAUDITWHEEL_exclude="libGL\*;libEGL\*"`: exclude shared libraries, that if vendored, may conflict (libGL\*;libEGL\*) with the system shared libraries.

  See [pypa/auditwheel](https://pypi.org/project/auditwheel/) for more information

## Testing our custom prebuilt binary

Open a new terminal.

### Prepare

Add your **Lua binary directory** to the PATH environment variable
```sh
export PATH="/io/luarocks-binaries-custom/lua-allegro5/out/prepublish/build/allegro5_lua-custom/out/install/Linux-GCC-Release/bin:$PATH"
```

Add your **LuaRocks binary directory** to the PATH environment variable
```sh
export PATH="/io/luarocks-binaries-custom/lua-allegro5/out/prepublish/build/allegro5_lua-custom/out/build.luaonly/Linux-GCC-Release/luarocks/luarocks-prefix/src/luarocks-build/bin:$PATH"
```

### Initialize our test project and install our custom prebuilt binary

```sh
mkdir -p /io/luarocks-binaries-custom/test/lua-allegro5 && \
cd /io/luarocks-binaries-custom/test/lua-allegro5 && \
luarocks --lua-version 5.1 init --lua-versions "5.1,5.2,5.3,5.4,5.5" && \
luarocks install --server=/io/luarocks-binaries-custom/server allegro5_lua-custom
```

### Test

Create a file `test-allegro5.lua`

```lua
--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/misc/install_test.c
--]]

local allegro5_lua = require("allegro5_lua")
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: undefined-global

local allegro = allegro5_lua.allegro5
if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: undefined-global
    allegro = require("allegro5_lua.al5_ffi")()
end

local fprintf = function(file, format, ...)
    file:write(string.format(format, ...))
end

local function INIT_CHECK(init_function, addon_name)
    local initialized = false
    local status, err = pcall(function()
        initialized = allegro[init_function]()
    end)

    if not status then
        fprintf(io.stderr, "Failed to initialize the %s addon.\n    %s\n", addon_name, err)
    elseif not initialized then
        fprintf(io.stderr, "Failed to initialize the %s addon.\n", addon_name)
    end
end

local function main()
    local version = allegro.al_get_allegro_version()
    local major = bit.rshift(version, 24)
    local minor = bit.band(bit.rshift(version, 16), 255)
    local revision = bit.band(bit.rshift(version, 8), 255)
    local release = bit.band(version, 255)

    fprintf(io.stderr, "Library version: %d.%d.%d.%d\n", major, minor, revision, release)
    fprintf(io.stderr, "Header version: %d.%d.%d.%d\n", allegro.ALLEGRO_VERSION, allegro.ALLEGRO_SUB_VERSION,
        allegro.ALLEGRO_WIP_VERSION, allegro.ALLEGRO_RELEASE_NUMBER)
    fprintf(io.stderr, "Header version string: %s\n", allegro.ALLEGRO_VERSION_STR)

    fprintf(io.stderr, "%s\n", allegro5_lua.allegro5.getBuildInformation())

    if not allegro.al_init() then
        fprintf(io.stderr, "Failed to initialize Allegro, probably a header/shared library version mismatch.\n")
        return -1
    end

    INIT_CHECK("al_init_font_addon", "font")
    INIT_CHECK("al_init_ttf_addon", "TTF")
    INIT_CHECK("al_init_image_addon", "image")
    INIT_CHECK("al_install_audio", "audio")
    INIT_CHECK("al_init_acodec_addon", "acodec")
    INIT_CHECK("al_init_native_dialog_addon", "native dialog")
    INIT_CHECK("al_init_primitives_addon", "primitives")
    INIT_CHECK("al_init_video_addon", "video")

    fprintf(io.stderr, "Everything looks good!\n")

    if allegro.al_is_system_installed() then
        allegro.al_uninstall_system()
    end
end

main()
```

Execute the `test-allegro5.lua` script

```cmd
./lua test-allegro5.lua
```

## Hosting on a web server

Alternatively, If you want an installation over http/s, upload the contents of **server directory** into an http/s server.

For example, if you uploaded it into http://example.com/binary-rock/, you can install the prebuilt binary with

```sh
luarocks install --server=http://example.com/binary-rock allegro5_lua-custom
```
