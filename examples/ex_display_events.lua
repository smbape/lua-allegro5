#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_display_events.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local MAX_EVENTS = 23

local events = {}

local function add_event(f, ...)
    for i = math.min(MAX_EVENTS - 1, #events), 1, -1 do
        events[i + 1] = events[i]
    end
    events[1] = string.format(f, ...)
end

local function main()
    local event = allegro5.ALLEGRO_EVENT()

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_init_primitives_addon()
    allegro5.al_install_mouse()
    allegro5.al_install_keyboard()
    allegro5.al_init_font_addon()

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_RESIZABLE)
    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Error creating display\n")
    end

    local font = allegro5.al_create_builtin_font()
    if not font then
        abort_example("Error creating builtin font\n")
    end

    local black = allegro5.al_map_rgb_f(0, 0, 0)
    local red = allegro5.al_map_rgb_f(1, 0, 0)
    local blue = allegro5.al_map_rgb_f(0, 0, 1)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    local done = false
    while not done do
        if allegro5.al_is_event_queue_empty(queue) then
            local x, y = 8, 28
            allegro5.al_clear_to_color(allegro5.al_map_rgb(0xff, 0xff, 0xc0))

            allegro5.al_draw_textf(font, blue, 8, 8, 0, "Display events (newest on top)")

            local color = red
            for i = 1, #events do
                allegro5.al_draw_textf(font, color, x, y, 0, "%s", events[i])
                color = black
                y = y + 20
            end
            allegro5.al_flip_display()
        end

        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_MOUSE_ENTER_DISPLAY then
            add_event("ALLEGRO_EVENT_MOUSE_ENTER_DISPLAY")
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_LEAVE_DISPLAY then
            add_event("ALLEGRO_EVENT_MOUSE_LEAVE_DISPLAY")
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                done = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            add_event("ALLEGRO_EVENT_DISPLAY_RESIZE x=%d, y=%d, "
                .. "width=%d, height=%d",
                event.display.x, event.display.y, event.display.width,
                event.display.height)
            allegro5.al_acknowledge_resize(event.display.source)
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            add_event("ALLEGRO_EVENT_DISPLAY_CLOSE")
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_LOST then
            add_event("ALLEGRO_EVENT_DISPLAY_LOST")
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_FOUND then
            add_event("ALLEGRO_EVENT_DISPLAY_FOUND")
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_SWITCH_OUT then
            add_event("ALLEGRO_EVENT_DISPLAY_SWITCH_OUT")
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_SWITCH_IN then
            add_event("ALLEGRO_EVENT_DISPLAY_SWITCH_IN")
        end
    end

    allegro5.al_destroy_event_queue(queue)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
