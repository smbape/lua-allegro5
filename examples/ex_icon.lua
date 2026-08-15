#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_icon.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    allegro5.al_install_keyboard()
    allegro5.al_init_image_addon()
    init_platform_specific()

    local display = allegro5.al_create_display(320, 200)
    if not display then
        abort_example("Error creating display\n")
    end
    allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))
    allegro5.al_flip_display()

    --[[ First icon: Read from file. --]]
    local icon1 = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/icon.tga")
    if not icon1 then
        abort_example("icon.tga not found\n")
    end

    --[[ Second icon: Create it. --]]
    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    local icon2 = allegro5.al_create_bitmap(16, 16)
    allegro5.al_set_target_bitmap(icon2)
    for i = 0, 255 do
        local u = i % 16
        local v = math.floor(i / 16)
        allegro5.al_put_pixel(u, v, allegro5.al_map_rgb_f(u / 15.0, v / 15.0, 1))
    end
    allegro5.al_set_target_backbuffer(display)

    allegro5.al_set_window_title(display, "Changing icon example")

    local timer = allegro5.al_create_timer(0.5)
    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_start_timer(timer)

    while true do
        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN and
            event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            allegro5.al_set_display_icon(display,
                (function()
                    if bit.band(event.timer.count, 1) ~= 0 then
                        return icon2
                    else
                        return icon1
                    end
                end)())
        end
    end

    allegro5.al_uninstall_system()

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
