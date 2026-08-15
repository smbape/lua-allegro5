#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

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
