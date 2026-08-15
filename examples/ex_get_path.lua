#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_get_path.c
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

local function show_path(id, label)
    local path = allegro5.al_get_standard_path(id)
    local path_str = path and allegro5.al_path_cstr(path, allegro5.ALLEGRO_NATIVE_PATH_SEP) or "<none>"
    log_printf("%s: %s\n", label, path_str)
    allegro5.al_destroy_path(path)
end

local function main()
    --[[ defaults to blank --]]
    allegro5.al_set_org_name("liballeg.org")

    --[[ defaults to the exename, set it here to remove the .exe on windows --]]
    allegro5.al_set_app_name("ex_get_path")

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    open_log()

    for pass = 1, 3 do
        if (pass == 1) then
            log_printf("With default exe name:\n")
        elseif (pass == 2) then
            log_printf("\nOverriding exe name to blahblah\n")
            allegro5.al_set_exe_name("blahblah")
        elseif (pass == 3) then
            log_printf("\nOverriding exe name to /tmp/blahblah.exe:\n")
            allegro5.al_set_exe_name("/tmp/blahblah.exe")
        end

        show_path(allegro5.ALLEGRO_RESOURCES_PATH, "RESOURCES_PATH")
        show_path(allegro5.ALLEGRO_TEMP_PATH, "TEMP_PATH")
        show_path(allegro5.ALLEGRO_USER_DATA_PATH, "USER_DATA_PATH")
        show_path(allegro5.ALLEGRO_USER_SETTINGS_PATH, "USER_SETTINGS_PATH")
        show_path(allegro5.ALLEGRO_USER_HOME_PATH, "USER_HOME_PATH")
        show_path(allegro5.ALLEGRO_USER_DOCUMENTS_PATH, "USER_DOCUMENTS_PATH")
        show_path(allegro5.ALLEGRO_EXENAME_PATH, "EXENAME_PATH")
    end

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
