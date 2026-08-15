#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_memfile.c
--]]

--[[
 -      Example program for the Allegro library.
 -
 -      Test memfile addon.
 --]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf
local new_array = common.new_array

local c_string = allegro5_lua.std.string

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    c_string = ffi.string
end

local function teardown(memfile)
    allegro5.al_fclose(memfile)

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

local function abort(memfile)
    teardown(memfile)
    os.exit(1)
end

local function main()
    local data_size = 1024
    local data, data_ptr = new_array("char", data_size)
    local buffer, buffer_ptr = new_array("char", 50)

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    log_printf("Creating memfile\n")
    local memfile = allegro5.al_open_memfile(data_ptr, data_size, "rw")
    if not memfile then
        log_printf("Error opening memfile :(\n")
        abort(memfile)
    end

    log_printf("Writing data to memfile\n")
    for i = 0, data_size / 4 - 1 do
        if allegro5.al_fwrite32le(memfile, i) < 4 then
            log_printf("Failed to write %i to memfile\n", i)
            abort(memfile)
        end
    end

    allegro5.al_fseek(memfile, 0, allegro5.ALLEGRO_SEEK_SET)

    log_printf("Reading and testing data from memfile\n")
    for i = 0, data_size / 4 - 1 do
        local ret = allegro5.al_fread32le(memfile)
        if ret ~= i or allegro5.al_feof(memfile) then
            log_printf("Item %i failed to verify, got %i\n", i, ret)
            abort(memfile)
        end
    end

    if allegro5.al_feof(memfile) then
        log_printf("EOF indicator prematurely set!\n")
        abort(memfile)
    end

    --[[ testing the ungetc buffer --]]
    allegro5.al_fseek(memfile, 0, allegro5.ALLEGRO_SEEK_SET)

    local i = 0
    while allegro5.al_fungetc(memfile, i) ~= allegro5.EOF do
        i = i + 1
    end
    log_printf("Length of ungetc buffer: %d\n", i)

    if allegro5.al_ftell(memfile) ~= -i then
        log_printf("Current position is not correct. Expected -%d, but got %d\n",
            i, allegro5.al_ftell(memfile))
        abort(memfile)
    end

    while i ~= 0 do
        i = i - 1
        if i ~= allegro5.al_fgetc(memfile) then
            log_printf("Failed to verify ungetc data.\n")
            abort(memfile)
        end
    end

    if allegro5.al_ftell(memfile) ~= 0 then
        log_printf("Current position is not correct after reading back the ungetc buffer\n")
        log_printf("Expected 0, but got %d\n", allegro5.al_ftell(memfile))
        abort(memfile)
    end

    allegro5.al_fputs(memfile, "legro rocks!")
    allegro5.al_fseek(memfile, 0, allegro5.ALLEGRO_SEEK_SET)
    allegro5.al_fungetc(memfile, string.byte('l'))
    allegro5.al_fungetc(memfile, string.byte('A'))
    allegro5.al_fgets(memfile, buffer_ptr, 15)
    if c_string(buffer_ptr) ~= "Allegro rocks!" then
        log_printf("Expected to see 'Allegro rocks!' but got '%s' instead.\n", c_string(buffer_ptr))
        log_printf("(Maybe the ungetc buffer isn't big enough.)\n")
        abort(memfile)
    end

    log_printf("Done.\n")

    teardown(memfile)
end

main()
