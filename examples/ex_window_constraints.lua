#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_window_constraints.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 -    Test program for Allegro.
 -
 -    Constrains the window to a minimum and or maximum.
 --]]

local function main()
    local event = allegro5.ALLEGRO_EVENT()
    local redraw = false
    local constr_min_w, constr_min_h, constr_max_w, constr_max_h = false, false, false, false

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_install_keyboard()
    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()

    allegro5.al_set_new_display_flags(bit.bor(allegro5.ALLEGRO_RESIZABLE,
        allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS))
    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Unable to set any graphic mode\n")
    end

    local bmp = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not bmp then
        abort_example("Unable to load image\n")
    end

    local f = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/a4_font.tga", 0, 0)
    if not f then
        abort_example("Failed to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/a4_font.tga\n")
    end

    local min_w = 640
    local min_h = 480
    local max_w = 800
    local max_h = 600
    constr_max_h = true; constr_max_w = constr_max_h; constr_min_h = constr_max_w; constr_min_w = constr_min_h

    if not allegro5.al_set_window_constraints(
            display,
            (function() if constr_min_w then return min_w else return 0 end end)(),
            (function() if constr_min_h then return min_h else return 0 end end)(),
            (function() if constr_max_w then return max_w else return 0 end end)(),
            (function() if constr_max_h then return max_h else return 0 end end)()) then
        abort_example("Unable to set window constraints.\n")
    end

    allegro5.al_apply_window_constraints(display, true)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())

    redraw = true
    while true do
        if redraw and allegro5.al_is_event_queue_empty(queue) then
            allegro5.al_clear_to_color(allegro5.al_map_rgb(255, 0, 0))
            allegro5.al_draw_scaled_bitmap(bmp,
                0, 0, allegro5.al_get_bitmap_width(bmp), allegro5.al_get_bitmap_height(bmp),
                0, 0, allegro5.al_get_display_width(display), allegro5.al_get_display_height(display),
                0)

            --[[ Display screen resolution --]]
            allegro5.al_draw_text(f, allegro5.al_map_rgb(255, 255, 255), 0, 0, 0,
                string.format("Resolution: %dx%d",
                    allegro5.al_get_display_width(display), allegro5.al_get_display_height(display)))

            local success, ret_min_w, ret_min_h, ret_max_w, ret_max_h = allegro5.al_get_window_constraints(display)
            if not success then
                abort_example("Unable to get window constraints\n")
            end

            allegro5.al_draw_text(f, allegro5.al_map_rgb(255, 255, 255), 0,
                allegro5.al_get_font_line_height(f), 0,
                string.format("Min Width: %d, Min Height: %d, Max Width: %d, Max Height: %d",
                    ret_min_w, ret_min_h, ret_max_w, ret_max_h))

            allegro5.al_draw_text(f, allegro5.al_map_rgb(255, 255, 255), 0,
                allegro5.al_get_font_line_height(f) * 2, 0,
                "Toggle Restriction: Min Width: Z, Min Height: X, Max Width: C, Max Height: V")

            allegro5.al_flip_display()
            redraw = false
        end

        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(event.display.source)
            redraw = true
        end
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_EXPOSE then
            redraw = true
        end
        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_Z then
                constr_min_w = not constr_min_w
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_X then
                constr_min_h = not constr_min_h
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_C then
                constr_max_w = not constr_max_w
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_V then
                constr_max_h = not constr_max_h
            end

            redraw = true

            if not allegro5.al_set_window_constraints(display,
                    (function() if constr_min_w then return min_w else return 0 end end)(),
                    (function() if constr_min_h then return min_h else return 0 end end)(),
                    (function() if constr_max_w then return max_w else return 0 end end)(),
                    (function() if constr_max_h then return max_h else return 0 end end)()) then
                abort_example("Unable to set window constraints.\n")
            end
            allegro5.al_apply_window_constraints(display, true)
        end
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
    end

    allegro5.al_destroy_bitmap(bmp)
    allegro5.al_destroy_display(display)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
