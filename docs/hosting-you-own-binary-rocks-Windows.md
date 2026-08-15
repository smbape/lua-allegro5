# Hosting you own binary rocks on Windows

## Table Of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Prerequisites](#prerequisites)
- [Build System Environment](#build-system-environment)
- [Open GIT BASH in the **build directory**](#open-git-bash-in-the-build-directory)
- [Download the source code](#download-the-source-code)
- [Build](#build)
- [Testing our custom prebuilt binary](#testing-our-custom-prebuilt-binary)
  - [Prepare](#prepare)
  - [Initialize our test project and install our custom prebuilt binary](#initialize-our-test-project-and-install-our-custom-prebuilt-binary)
  - [Test](#test)
- [Hosting on a web server](#hosting-on-a-web-server)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

Here we will build a custom opencv with the folling modifications:
  - Enable unstable API

The procedure has been tested on:
  - Windows 11.

## Prerequisites

  - Install [CMake >= 3.25](https://cmake.org/download/)
  - Install [Git](https://git-scm.com/)
  - Install [NodeJS](https://nodejs.org/en/download/current)
  - Install [Python](https://www.python.org/downloads/)
  - Install [Visual Studio 2026](https://visualstudio.microsoft.com/fr/downloads/)

In your windows search, search and open the `x64 Native Tools Command Prompt for VS`

From here on, commands will be executed within the opened Command Prompt.

## Build System Environment

We will name our LuaRocks pakcage **allegro5_lua-custom** in order to avoid conflict with the original package name

In this example, we will use the following directories: 
  - The **Lua binary directory** is _D:\luarocks-binaries-custom\lua-allegro5\out\prepublish\build\allegro5_lua-custom\out\install\x64-Release\bin_
  - The **LuaRocks binary directory** is _D:\luarocks-binaries-custom\lua-allegro5\out\prepublish\build\allegro5_lua-custom\out\build.luaonly\x64-Release\luarocks\luarocks-prefix\src\luarocks_
  - The **build directory** is _D:\luarocks-binaries-custom\build_
  - The **server directory** is _D:\luarocks-binaries-custom\server_
  - The **test directory** is _D:\luarocks-binaries-custom\test_

## Open GIT BASH in the **build directory**

```cmd
"%ProgramW6432%\Git\bin\bash.exe" -l -i
```

## Download the source code

```sh
git clone --depth 1 --branch v0.0.1 https://github.com/smbape/lua-allegro5.git /d/luarocks-binaries-custom/lua-allegro5 && \
cd /d/luarocks-binaries-custom/lua-allegro5 && \
npm ci
```

## Build

```sh
# --lua-versions luajit-2.1,5.1,5.2,5.3,5.4,5.5
TMPDIR=/d/luarocks-binaries-custom/tmp && \
node scripts/prepublish.js --pack --server="/d/luarocks-binaries-custom/server" --lua-versions luajit-2.1 --name=allegro5_lua-custom \
    -DENABLE_REPAIR=ON \
    -DCMAKE_TOOLCHAIN_FILE="$(cygpath -m "$VCPKG_ROOT")/scripts/buildsystems/vcpkg.cmake"
```

## Testing our custom prebuilt binary

Open a new Command Prompt terminal. It doesn't have to be a Visual Studio command prompt

### Prepare

Add your **Lua binary directory** to the PATH environment variable
```cmd
set PATH=D:\luarocks-binaries-custom\lua-allegro5\out\prepublish\build\allegro5_lua-custom\out\install\x64-Release\bin;%PATH%
```

Add your **LuaRocks binary directory** to the PATH environment variable
```cmd
set PATH=D:\luarocks-binaries-custom\lua-allegro5\out\prepublish\build\allegro5_lua-custom\out\build.luaonly\x64-Release\luarocks\luarocks-prefix\src\luarocks;%PATH%
```

### Initialize our test project and install our custom prebuilt binary

```cmd
mkdir "D:\luarocks-binaries-custom\test"
cd /d "D:\luarocks-binaries-custom\test"
luarocks --lua-version "5.1" init --lua-versions "5.1,5.2,5.3,5.4,5.5"
luarocks install "--server=D:\luarocks-binaries-custom\server" allegro5_lua-custom
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
lua.bat test-allegro5.lua
```

## Hosting on a web server

Alternatively, If you want an installation over http/s, upload the contents of **server directory** into an http/s server.

For example, if you uploaded it into http://example.com/binary-rock/, you can install the prebuilt binary with

```sh
luarocks install --server=http://example.com/binary-rock allegro5_lua-custom
```
