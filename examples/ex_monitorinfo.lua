#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_monitorinfo.c
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

local function main()
    local info = allegro5.ALLEGRO_MONITOR_INFO()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    local num_adapters = allegro5.al_get_num_video_adapters()

    log_printf("%d adapters found...\n", num_adapters)

    for i = 0, num_adapters - 1 do
        allegro5.al_get_monitor_info(i, info)
        log_printf("Adapter %d: ", i)
        local dpi = allegro5.al_get_monitor_dpi(i)
        log_printf("(%d, %d) - (%d, %d) - dpi: %d\n", info.x1, info.y1, info.x2, info.y2, dpi)
        allegro5.al_set_new_display_adapter(i)
        log_printf("   Available fullscreen display modes:\n")
        for j = 0, allegro5.al_get_num_display_modes() - 1 do
            local mode = allegro5.ALLEGRO_DISPLAY_MODE()
            allegro5.al_get_display_mode(j, mode)

            log_printf("   Mode %3d: %4d x %4d, %d Hz\n",
                j, mode.width, mode.height, mode.refresh_rate)
        end
    end

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
