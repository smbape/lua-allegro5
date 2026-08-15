#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_path.c
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

local function done()
    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

local function main(argv)
    local argc = #argv

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    if argc < 1 then
        local exe = allegro5.al_create_path(argv[0])
        if exe then
            log_printf("This example needs to be run from the command line.\nUsage1: %s <path>\n",
                allegro5.al_get_path_filename(exe))
            allegro5.al_destroy_path(exe)
        else
            log_printf("This example needs to be run from the command line.\nUsage2: %s <path>\n", argv[0])
        end
        done()
        return
    end

    local dyn = allegro5.al_create_path(argv[1])
    if not dyn then
        log_printf("Failed to create path structure for '%s'.\n", argv[1])
    else
        log_printf("dyn: drive=\"%s\", file=\"%s\"\n",
            allegro5.al_get_path_drive(dyn),
            allegro5.al_get_path_filename(dyn))
        allegro5.al_destroy_path(dyn)
    end

    local tostring = allegro5.al_create_path(argv[1])
    if not tostring then
        log_printf("Failed to create path structure for tostring test\n")
    else
        log_printf("tostring: '%s'\n", allegro5.al_path_cstr(tostring, '/'))
        log_printf("tostring: drive:'%s'", allegro5.al_get_path_drive(tostring))
        log_printf(" dirs:")
        for i = 0, allegro5.al_get_path_num_components(tostring) - 1 do
            if i > 0 then
                log_printf(",")
            end
            log_printf(" '%s'", allegro5.al_get_path_component(tostring, i))
        end
        log_printf(" filename:'%s'\n", allegro5.al_get_path_filename(tostring))
        allegro5.al_destroy_path(tostring)
    end

    --[[ FIXME: test out more of the allegro.al_path_ functions, ie: insert, remove,
     concat, relative
    --]]

    dyn = allegro5.al_create_path(argv[1])
    if dyn then
        local cloned = allegro5.al_clone_path(dyn)
        if cloned then
            log_printf("dyn: '%s'\n", allegro5.al_path_cstr(dyn, '/'))

            allegro5.al_make_path_canonical(cloned)
            log_printf("can: '%s'\n", allegro5.al_path_cstr(cloned, '/'))

            allegro5.al_destroy_path(dyn)
            allegro5.al_destroy_path(cloned)
        else
            log_printf("failed to clone ALLEGRO_PATH :(\n")
            allegro5.al_destroy_path(dyn)
        end
    else
        log_printf("failed to create new ALLEGRO_PATH for cloning...\n")
    end

    done()
end

main(rawget(_G, "arg") or {})
