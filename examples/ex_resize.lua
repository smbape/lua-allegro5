#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_resize.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local function redraw()
    local black, white = allegro5.ALLEGRO_COLOR(), allegro5.ALLEGRO_COLOR()
    local w, h = 0, 0

    white = allegro5.al_map_rgba_f(1, 1, 1, 1)
    black = allegro5.al_map_rgba_f(0, 0, 0, 1)

    allegro5.al_clear_to_color(white)
    w = allegro5.al_get_bitmap_width(allegro5.al_get_target_bitmap())
    h = allegro5.al_get_bitmap_height(allegro5.al_get_target_bitmap())
    allegro5.al_draw_line(0, h, w / 2, 0, black, 0)
    allegro5.al_draw_line(w / 2, 0, w, h, black, 0)
    allegro5.al_draw_line(w / 4, h / 2, 3 * w / 4, h / 2, black, 0)
    allegro5.al_flip_display()
end

local function main()
    local display
    local timer
    local events
    local event = allegro5.ALLEGRO_EVENT()
    local rs = 100
    local resize = false

    --[[ Initialize Allegro and create an event queue. --]]
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    allegro5.al_init_primitives_addon()
    events = allegro5.al_create_event_queue()

    --[[ Setup a display driver and register events from it. --]]
    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_RESIZABLE)
    display = allegro5.al_create_display(rs, rs)
    if not display then
        abort_example("Could not create display.\n")
    end
    allegro5.al_register_event_source(events, allegro5.al_get_display_event_source(display))

    timer = allegro5.al_create_timer(0.1)
    allegro5.al_start_timer(timer)

    --[[ Setup a keyboard driver and register events from it. --]]
    allegro5.al_install_keyboard()
    allegro5.al_register_event_source(events, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(events, allegro5.al_get_timer_event_source(timer))

    --[[ Display a pulsating window until a key or the closebutton is pressed. --]]
    redraw()
    while true do
        if resize then
            local s = 0
            rs = rs + 10
            if rs == 300 then
                rs = 100
            end
            s = rs
            if s > 200 then
                s = 400 - s
            end
            allegro5.al_resize_display(display, s, s)
            redraw()
            resize = false
        end
        allegro5.al_wait_for_event(events, event)
        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            resize = true
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            break
        end
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
