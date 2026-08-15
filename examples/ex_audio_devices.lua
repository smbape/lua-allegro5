#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_audio_devices.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ This example lists the available audio devices.
 --]]
-- #define ALLEGRO_UNSTABLE

local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    if not allegro5.al_install_audio() then
        abort_example("Could not init sound!\n")
    end

    open_log()

    local count = allegro5.al_get_num_audio_output_devices()
    if count < 0 then
        log_printf("Platform not supported.\n")
    else
        for i = 0, count - INDEX_BASE do
            local device = allegro5.al_get_audio_output_device(i)
            log_printf("%s\n", allegro5.al_get_audio_device_name(device))
        end
    end

    allegro5.al_uninstall_audio()

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
