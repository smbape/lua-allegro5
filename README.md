# Allegro5 bindings for lua

Allegro5 bindings for luajit and lua 5.1/5.2/5.3/5.4/5.5.

The aim is to make it colse a as possible to the c-api.

Therefore the [Allegro5 documentation](https://liballeg.org/a5docs/5.2.11.3/index.html) should be the reference.

## Table Of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Installation](#installation)
  - [Prerequisites to source rock install](#prerequisites-to-source-rock-install)
    - [Windows](#windows)
    - [Linux](#linux)
      - [Debian, Ubuntu](#debian-ubuntu)
      - [Fedora](#fedora)
      - [Almalinux 8](#almalinux-8)
      - [Almalinux 9, 10](#almalinux-9-10)
  - [How to install](#how-to-install)
- [Examples](#examples)
  - [Game loop example](#game-loop-example)
- [Running examples](#running-examples)
  - [Prerequisites to run examples](#prerequisites-to-run-examples)
    - [Windows](#windows-1)
    - [Linux](#linux-1)
  - [Initialize the project](#initialize-the-project)
    - [Windows](#windows-2)
    - [Linux](#linux-2)
- [Hosting you own binary rocks](#hosting-you-own-binary-rocks)
- [How to translate c/c++ code](#how-to-translate-cc-code)
  - [C code](#c-code)
  - [Lua equivalent](#lua-equivalent)
- [Lua Gotchas](#lua-gotchas)
  - [1-indexed](#1-indexed)
  - [Integer division](#integer-division)
  - [%d in string formats](#%25d-in-string-formats)
  - [0 is not falsy](#0-is-not-falsy)
  - [Structures are passed by reference not by copy](#structures-are-passed-by-reference-not-by-copy)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Installation

Prebuilt binaries are available for [LuaJIT 2.1](https://luajit.org/) and [Lua 5.1/5.2/5.3/5.4/5.5](https://www.lua.org/versions.html), and only on Windows and Linux.

### Prerequisites to source rock install

#### Windows

  - Install [Git](https://git-scm.com/)
  - Install [LuaRocks](https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Windows)
  - Install [NodeJS](https://nodejs.org/en/download/current)
  - Install [Python](https://www.python.org/downloads/)
  - Install [Visual Studio 2026 with .NET Desktop and C++ Desktop](https://visualstudio.microsoft.com/fr/downloads/)
  - Install [DirectX Software Development Kit](https://www.microsoft.com/en-us/download/details.aspx?id=6812)
  - In your windows search, search and open the `x64 Native Tools Command Prompt for VS`
  - Export vcpkg toolchain variable `set ALLEGRO5_LUA_CMAKE_TOOLCHAIN_FILE=%VCPKG_ROOT%/scripts/buildsystems/vcpkg.cmake`
  - Tell luarocks to use Ninja as cmake generator `luarocks config --scope project cmake_generator Ninja`

#### Linux

  - Install [CMake >= 3.25](https://cmake.org/download/)
  - Install [LuaRocks](https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Unix)
  - Install [Ninja](https://ninja-build.org/)
  - Install [NodeJS](https://nodejs.org/en/download/current)
  - Install [vcpkg](https://learn.microsoft.com/en-us/vcpkg/get_started/get-started?pivots=shell-bash)
  - Export vcpkg toolchain variable `export ALLEGRO5_LUA_CMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake"`
  - Install needed packages (see below for you corresponding distribution).
  - Tell luarocks to use [Ninja](https://ninja-build.org/) as cmake generator `luarocks config --scope project cmake_generator Ninja`

##### Debian, Ubuntu

```sh
sudo apt install -y build-essential curl git libgles-dev libgles-dev libxcursor-dev patchelf pkg-config python3-pip python3-venv unzip wget zip
```

##### Fedora

```sh
sudo dnf install -y \
    autoconf autoconf-archive automake libtool \
    git make readline-devel libXcursor-devel patch pkg-config unzip wget zip \
    flac-devel freeimage-devel freetype-devel harfbuzz-devel libopenmpt-devel libtheora-devel \
    libvorbis-devel libwebp-devel openal-soft-devel physfs-devel turbojpeg-devel \
    curl gcc gcc-c++ patchelf python3-pip \
```

##### Almalinux 8

```sh
sudo dnf install -y \
    autoconf autoconf-archive automake libtool \
    git make readline-devel libXcursor-devel patch pkg-config unzip wget zip \
    flac-devel freeimage-devel freetype-devel harfbuzz-devel libopenmpt-devel libtheora-devel \
    libvorbis-devel libwebp-devel openal-soft-devel physfs-devel turbojpeg-devel && \
sudo config-manager --set-enabled powertools && \
sudo dnf install -y epel-release && \
sudo dnf install -y https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm
sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm && \
sudo dnf update -y && \
sudo dnf install -y gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ patchelf python3.12-pip && \
source curl 
```

##### Almalinux 9, 10

```sh
sudo dnf install -y \
    autoconf autoconf-archive automake libtool \
    git make readline-devel libXcursor-devel patch pkg-config unzip wget zip \
    flac-devel freeimage-devel freetype-devel harfbuzz-devel libopenmpt-devel libtheora-devel \
    libvorbis-devel libwebp-devel openal-soft-devel physfs-devel turbojpeg-devel && \
sudo config-manager --set-enabled crb && \
sudo dnf install -y epel-release && \
sudo dnf install -y https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-9.noarch.rpm
sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-9.noarch.rpm && \
sudo dnf update -y && \
sudo dnf install -y curl gcc gcc-c++ patchelf python3-pip
```

### How to install

I recommend you to try to install the prebuilt binary.

If you are not using luajit

```sh
luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 allegro5_lua
```

Or to specify the target lua version with one of the following commands

```sh
luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 allegro5_lua 5.2.11.3luajit2.1
luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 allegro5_lua 5.2.11.3lua5.5
luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 allegro5_lua 5.2.11.3lua5.4
luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 allegro5_lua 5.2.11.3lua5.3
luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 allegro5_lua 5.2.11.3lua5.2
luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 allegro5_lua 5.2.11.3lua5.1
```

Those prebuilt binaries should work on Windows and many linux distributions and have been tested on:
  - Windows 11
  - Ubuntu 22.04
  - Ubuntu 24.04
  - Ubuntu 26.04
  - Debian 11
  - Debian 12
  - Debian 13
  - Fedora 43
  - Fedora 44
  - Fedora 45
  - Almalinux 8
  - Almalinux 9
  - Almalinux 10

If none of the above works for you, then install the source rock with

```sh
luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 allegro5_lua 5.2.11.3
```

## Examples

More expamples can be found in the [expamples](expamples) directory.

### Game loop example

```lua
local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5

-- For a faster runtime, use luajit FFI Library when possible
if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then
    allegro5 = require("allegro5_lua.al5_ffi")()
end

local function main()
    local FPS = 60
    local w, h = 800, 600

    if not allegro5.al_init() then
        error("Failed to init Allegro")
    end

    allegro5.al_init_font_addon()
    local font = allegro5.al_create_builtin_font()

    local display = allegro5.al_create_display(w, h)
    if not display then
        error("Error creating display")
    end

    local timer = allegro5.al_create_timer(1.0 / FPS)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    local done = false
    local redraw = true

    allegro5.al_start_timer(timer)

    while not done do
        if redraw and allegro5.al_is_event_queue_empty(queue) then
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0.0, 0.0, 0.0))
            allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1.0, 1.0, 1.0),
                allegro5.al_get_display_width(display) / 2, allegro5.al_get_display_height(display) / 2,
                allegro5.ALLEGRO_ALIGN_CENTER, "Welcome to Allegro!")
            allegro5.al_flip_display()
            redraw = false
        end

        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                done = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            done = true
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        end
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
```

## Running examples

### Prerequisites to run examples

#### Windows

  - Install [Git](https://git-scm.com/)
  - Install [NodeJS](https://nodejs.org/en/download/current)
  - Install [Visual Studio 2026 with '.NET desktop development' and 'Desktop development with C++'](https://visualstudio.microsoft.com/fr/downloads/)
  - In your windows search, search and open the `x64 Native Tools Command Prompt for VS`

#### Linux

  - Install [NodeJS](https://nodejs.org/en/download/current)
  - Install [CMake >= 3.25](https://cmake.org/download/)
  - Install [Ninja](https://ninja-build.org/)
  - Install needed packages:
    - Debian, Ubuntu: `sudo apt install -y curl g++ gcc git libgl1 libglib2.0-0 libreadline-dev libsm6 libxext6 make python3-pip python3-venv unzip wget`
    - Fedora, Almalinux 9, Almalinux 10: `sudo dnf install -y curl gcc gcc-c++ git glib2 readline-devel libglvnd-glx libSM libXext make patch python3-pip unzip wget`
    - Almalinux 8: `sudo dnf install -y curl gcc gcc-c++ git glib2 readline-devel libglvnd-glx libSM libXext make patch python3.12-pip unzip wget`

### Initialize the project

#### Windows

```cmd
git clone --depth 1 --branch v0.0.1 https://github.com/smbape/lua-allegro5.git
cd lua-allegro5
@REM build.bat "-DLua_VERSION=luajit-2.1" --target luajit --install
@REM available versions are 5.1, 5.2, 5.3, 5.4, 5.5
build.bat "-DLua_VERSION=5.5" --target lua --install
build.bat "-DLua_VERSION=5.5" --target luarocks
@REM luarocks\luarocks.bat install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 allegro5_lua 5.2.11.3luajit2.1
luarocks\luarocks.bat install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 allegro5_lua
luarocks\luarocks.bat install --deps-only samples\samples-scm-1.rockspec
npm ci
node scripts\test.js --Release
```

#### Linux

```sh
git clone --depth 1 --branch v0.0.1 https://github.com/smbape/lua-allegro5.git
cd lua-allegro5
# ./build.sh "-DLua_VERSION=luajit-2.1" --target luajit --install
# available versions are 5.1, 5.2, 5.3, 5.4, 5.5
./build.sh "-DLua_VERSION=5.5" --target lua --install
./build.sh "-DLua_VERSION=5.5" --target luarocks
# ./luarocks/luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 allegro5_lua 5.2.11.3luajit2.1
./luarocks/luarocks install --server=https://github.com/smbape/luarocks-binaries/releases/download/v0.0.1 allegro5_lua
./luarocks/luarocks install --deps-only samples/samples-scm-1.rockspec
npm ci
node scripts/test.js --Release
```

## Hosting you own binary rocks

If the provided binray rocks are not suitable for your environnment, you can install the source rock.  
However, installing the source rock takes a long time (20 mn - 14 mn vcpkg + 6 mn allegro).  
Therefore, it is not practical to repeat that process again.  
To avoid that long install time, you can host your own prebuilt binary rocks on a private server.

Windows: [Hosting you own binary rocks on Windows](docs/hosting-you-own-binary-rocks-Windows.md)

Linux: [Hosting you own binary rocks on Linux](docs/hosting-you-own-binary-rocks-Linux.md)

## How to translate c/c++ code

Translation is usually straight forward from c, minus some lua gotchas.

Output variables are returned in their order of apperance.

Because of my lack of proficiency in c/c++, after `al_init`, `al_uninstall_system` must be explicitely called in order to terminate the program.

### C code

```c
float r, g, b;
al_unmap_rgb_f(color, &r, &g, &b);
```

```c
#include <allegro5/allegro.h>
#include <allegro5/allegro_font.h>
#include <allegro5/allegro_color.h>

int main(int argc, char **argv)
{
    ALLEGRO_TIMER *timer;
    ALLEGRO_EVENT_QUEUE *queue;
    ALLEGRO_FONT *font;
    ALLEGRO_DISPLAY *display;
    int w = 1280, h = 720;
    bool done = false;
    bool redraw = true;

    (void)argc;
    (void)argv;

    if (!al_init()) {
        abort_example("Failed to init Allegro.\n");
    }

    al_init_font_addon();
    font = al_create_builtin_font();

    init_platform_specific();

    display = al_create_display(w, h);
    if (!display) {
        abort_example("Error creating display.\n");
    }

    al_install_keyboard();

    timer = al_create_timer(1.0 / FPS);

    queue = al_create_event_queue();
    al_register_event_source(queue, al_get_mouse_event_source());
    al_register_event_source(queue, al_get_keyboard_event_source());
    al_register_event_source(queue, al_get_timer_event_source(timer));

    al_register_event_source(queue, al_get_display_event_source(display));

    al_start_timer(timer);

    while (!done) {
        ALLEGRO_EVENT event;

        if (redraw && al_is_event_queue_empty(queue)) {
            al_clear_to_color(al_map_rgb_f(0.0, 0.0, 0.0));
            al_draw_text(font, al_map_rgb_f(1.0, 1.0, 1.0),
                al_get_display_width(display) / 2, al_get_display_height(display) / 2,
                ALLEGRO_ALIGN_CENTER, "Welcome to Allegro!");
            al_flip_display();
            redraw = false;
        }

        al_wait_for_event(queue, &event);
        switch (event.type) {
            case ALLEGRO_EVENT_KEY_CHAR:
                if (event.keyboard.keycode == ALLEGRO_KEY_ESCAPE)
                    done = true;
                break;

            case ALLEGRO_EVENT_DISPLAY_CLOSE:
                done = true;
                break;

            case ALLEGRO_EVENT_TIMER:
                update();
                redraw = true;
                break;
        }
    }
}

```

### Lua equivalent

```lua
local r, g, b = allegro5.al_unmap_rgb_f(color)
```

```lua
local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5

-- For a faster runtime, use luajit FFI Library when possible
if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then
    allegro5 = require("allegro5_lua.al5_ffi")()
end

local function main()
    local FPS = 60
    local w, h = 800, 600

    if not allegro5.al_init() then
        error("Failed to init Allegro")
    end

    allegro5.al_init_font_addon()
    local font = allegro5.al_create_builtin_font()

    local display = allegro5.al_create_display(w, h)
    if not display then
        error("Error creating display")
    end

    local timer = allegro5.al_create_timer(1.0 / FPS)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    local done = false
    local redraw = true

    allegro5.al_start_timer(timer)

    while not done do
        if redraw and allegro5.al_is_event_queue_empty(queue) then
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0.0, 0.0, 0.0))
            allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1.0, 1.0, 1.0),
                allegro5.al_get_display_width(display) / 2, allegro5.al_get_display_height(display) / 2,
                allegro5.ALLEGRO_ALIGN_CENTER, "Welcome to Allegro!")
            allegro5.al_flip_display()
            redraw = false
        end

        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                done = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            done = true
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        end
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
```

## Lua Gotchas

### 1-indexed

Arrays are 1-indexed in `lua`, and 0-indexed in c/c++. Therefore, if you see in c/c++ `p[0]` for arrays or tuples, you should write in lua `p[1]`

### Integer division

In c/c++, dividing integers result in integers. In `lua`, numbers are doubles.

```c
int th;
int i;
...
i = (y - MARGIN_TOP) / th;
```

```lua
local th
local i
...
i = math.floor((y - MARGIN_TOP) / th)
```

### %d in string formats

Lua < 5.3 has no integer type, therefore, %d will not work.  
`string.format` should be called before passing the string to the c function.

```c
   al_draw_textf(example.font, example.white, 0, 0, 0, "count: %d",
      example.sprite_count);
```

```lua
   allegro.al_draw_text(example.font, example.white, 0, 0, 0, string.format("count: %d",
      example.sprite_count))
```

### 0 is not falsy

In c/c++, it is common to implicitely cast bit operations results as boolean

```c
if (flag_names[i]) {
    if (flags & (1 << i)) c = al_map_rgb_f(0.5, 0, 0);
    else if (old_flags & (1 << i)) c = al_map_rgb_f(0.5, 0.4, 0.4);
    else continue;
    al_draw_text(font, c, x, y, 0, flag_names[i]);
    x += al_get_text_width(font, flag_names[i]) + 10;
}
```

However, in `lua`, `0` is not equivalent to false.  
Results must be explicitely compared to `0`

```lua
if flag_names[i + 1] then
    local continue = false

    if bit.band(flags, (bit.lshift(1, i))) ~= 0 then
        c = allegro.al_map_rgb_f(0.5, 0, 0)
        -- continue = false
    elseif bit.band(old_flags, (bit.lshift(1, i))) ~= 0 then
        c = allegro.al_map_rgb_f(0.5, 0.4, 0.4)
        -- continue = false
    else
        continue = true
    end

    if not continue then
        allegro.al_draw_text(font, c, x, y, 0, flag_names[i + 1])
        x = x + allegro.al_get_text_width(font, flag_names[i + 1]) + 10
    end
end
```

### Structures are passed by reference not by copy

In c,

```c
ALLEGRO_COLOR rgba = ex.foreground; // Copy
```

In lua,

```lua
local allegro5_lua = require("allegro5_lua")
local allegro = allegro5_lua.allegro5
local memcpy = allegro5_lua.C.memcpy

local copy = function(ctor, other)
    local copied = ctor()
    memcpy(copied, other, ctor.__sizeof)
    return copied
end

local rgba = copy(allegro.ALLEGRO_COLOR, ex.foreground) -- copy
```
