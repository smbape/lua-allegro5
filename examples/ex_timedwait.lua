#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_timedwait.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 -    Example program for the Allegro library, by Peter Wang.
 -
 -    Test timed version of al_wait_for_event().
 --]]


local function test_relative_timeout(font, queue)
    local event = allegro5.ALLEGRO_EVENT()
    local shade = 0.1

    while true do
        if allegro5.al_wait_for_event_timed(queue, event, 0.1) then
            if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
                if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                    return true
                else
                    shade = 0.0
                end
            elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
                return false
            end
        else
            --[[ timed out --]]
            shade = shade + 0.1
            if shade > 1.0 then
                shade = 1.0
            end
        end

        allegro5.al_clear_to_color(allegro5.al_map_rgba_f(0.5 * shade, 0.25 * shade, shade, 0))
        allegro5.al_draw_textf(font, allegro5.al_map_rgb_f(1., 1., 1.), 320, 240, allegro5.ALLEGRO_ALIGN_CENTRE,
            "Relative timeout (%.2f)", shade)
        allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1., 1., 1.), 320, 260, allegro5.ALLEGRO_ALIGN_CENTRE,
            "Esc to move on, Space to restart.")
        allegro5.al_flip_display()
    end
end


local function test_absolute_timeout(font, queue)
    local timeout = allegro5.ALLEGRO_TIMEOUT()
    local event = allegro5.ALLEGRO_EVENT()
    local shade = 0.1
    local ret = false

    while true do
        allegro5.al_init_timeout(timeout, 0.1)
        while ((function()
                ret = allegro5.al_wait_for_event_until(queue, event, timeout)
                return ret
            end)()) do
            if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
                if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                    return true
                else
                    shade = 0.
                end
            elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
                return false
            end
        end

        if not ret then
            --[[ timed out --]]
            shade = shade + 0.1
            if shade > 1.0 then
                shade = 1.0
            end
        end

        allegro5.al_clear_to_color(allegro5.al_map_rgba_f(shade, 0.5 * shade, 0.25 * shade, 0))
        allegro5.al_draw_textf(font, allegro5.al_map_rgb_f(1., 1., 1.), 320, 240, allegro5.ALLEGRO_ALIGN_CENTRE,
            "Absolute timeout (%.2f)", shade)
        allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1., 1., 1.), 320, 260, allegro5.ALLEGRO_ALIGN_CENTRE,
            "Esc to move on, Space to restart.")
        allegro5.al_flip_display()
    end
end


local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    if not allegro5.al_init_font_addon() then
        abort_example("Could not init Font addon.\n")
    end

    allegro5.al_install_keyboard()

    local dpy = allegro5.al_create_display(640, 480)
    if not dpy then
        abort_example("Could not create a display.\n")
    end

    local font = allegro5.al_create_builtin_font()
    if not font then
        abort_example("Could not create builtin font.\n")
    end

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(dpy))

    while true do
        if not test_relative_timeout(font, queue) then
            break
        end
        if not test_absolute_timeout(font, queue) then
            break
        end
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
