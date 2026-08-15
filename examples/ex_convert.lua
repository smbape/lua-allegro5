#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_convert.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ Image conversion example --]]

local function done(code)
    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end

    os.exit(code)
end

local function main(argv)
    local argc = #argv

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    if argc < 2 then
        log_printf("This example needs to be run from the command line.\n")
        log_printf("Usage: %s <infile> <outfile>\n", argv[0])
        log_printf("\tPossible file types: BMP PCX PNG TGA\n")
        done(1)
        return
    end

    allegro5.al_init_image_addon()

    allegro5.al_set_new_bitmap_format(allegro5.ALLEGRO_PIXEL_FORMAT_ARGB_8888)
    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)

    local bitmap = allegro5.al_load_bitmap_flags(argv[1], allegro5.ALLEGRO_NO_PREMULTIPLIED_ALPHA)
    if not bitmap then
        log_printf("Error loading input file\n")
        done(1)
        return
    end

    local t0 = allegro5.al_get_time()
    if not allegro5.al_save_bitmap(argv[2], bitmap) then
        log_printf("Error saving bitmap\n")
        done(1)
        return
    end
    local t1 = allegro5.al_get_time()
    log_printf("Saving took %.4f seconds\n", t1 - t0)

    allegro5.al_destroy_bitmap(bitmap)
    done(0)
end

main(rawget(_G, "arg") or {})
