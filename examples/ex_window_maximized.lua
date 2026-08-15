#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_window_maximized.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local abort_example = common.abort_example

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 - ex_window_maximized.c - create the maximized, resizable window.
 - Press SPACE to change constraints.
 --]]

local DISPLAY_W = 640
local DISPLAY_H = 480

--[[ comment out to use GTK backend --]]
local USE_GTK = false

local use_constraints


local function draw_information(display, font, color)
    allegro5.al_draw_textf(font, color, 20, 20, 0, "Hotkeys:")
    allegro5.al_draw_textf(font, color, 30, 30, 0, "enabled/disable constraints: ENTER")
    allegro5.al_draw_textf(font, color, 30, 40, 0, "change constraints: SPACE")

    allegro5.al_draw_text(font, color, 20, 50, 0,
        string.format("Resolution: %dx%d",
            allegro5.al_get_display_width(display),
            allegro5.al_get_display_height(display)))

    local sucess, min_w, min_h, max_w, max_h = allegro5.al_get_window_constraints(display)
    if sucess then
        allegro5.al_draw_textf(font, color, 20, 60, 0, "Constraints: %s",
            (function() if use_constraints then return "Enabled" else return "Disabled" end end)())
        allegro5.al_draw_text(font, color, 20, 70, 0, string.format("min_w = %d min_h = %d",
            min_w, min_h))
        allegro5.al_draw_text(font, color, 20, 80, 0, string.format("max_w = %d max_h = %d",
            max_w, max_h))
    end
end

local function main()
    local done = false
    local redraw = true
    use_constraints = true

    if not allegro5.al_init() then
        abort_example("Failed to init Allegro.\n")
    end

    if not allegro5.al_init_primitives_addon() then
        abort_example("Failed to init primitives addon.\n")
    end

    if not allegro5.al_init_image_addon() then
        abort_example("Failed to init image addon.\n")
    end

    if not allegro5.al_init_font_addon() then
        abort_example("Failed to init font addon.\n")
    end

    local display_flags = bit.bor(allegro5.ALLEGRO_WINDOWED
    , bit.bor(allegro5.ALLEGRO_RESIZABLE, bit.bor(allegro5.ALLEGRO_MAXIMIZED
    , allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS)))
    if USE_GTK then
        display_flags = bit.bor(display_flags, allegro5.ALLEGRO_GTK_TOPLEVEL)
    end
    allegro5.al_set_new_display_flags(display_flags)

    --[[ creating really small display --]]
    local display = allegro5.al_create_display(math.floor(DISPLAY_W / 3), math.floor(DISPLAY_H / 3))
    if not display then
        abort_example("Error creating display.\n")
    end

    --[[ set lower limits for constraints only --]]
    if not allegro5.al_set_window_constraints(display, math.floor(DISPLAY_W / 2), math.floor(DISPLAY_H / 2), 0, 0) then
        abort_example("Unable to set window constraints.\n")
    end
    allegro5.al_apply_window_constraints(display, use_constraints)

    if not allegro5.al_install_keyboard() then
        abort_example("Error installing keyboard.\n")
    end

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    local color_1 = allegro5.al_map_rgb(255, 127, 0)
    local color_2 = allegro5.al_map_rgb(0, 255, 0)
    local color = color_1
    local color_text = allegro5.al_map_rgb(0, 0, 0)

    local font = allegro5.al_create_builtin_font()

    while not done do
        local event = allegro5.ALLEGRO_EVENT()

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            redraw = false
            local x2 = allegro5.al_get_display_width(display) - 10
            local y2 = allegro5.al_get_display_height(display) - 10
            allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))
            allegro5.al_draw_filled_rectangle(10, 10, x2, y2, color)
            draw_information(display, font, color_text)
            allegro5.al_flip_display()
        end

        allegro5.al_wait_for_event(queue, event)


        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                done = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_UP then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
                redraw = true

                if color == color_1 then
                    if not allegro5.al_set_window_constraints(display,
                            0, 0,
                            DISPLAY_W, DISPLAY_H)
                    then
                        abort_example("Unable to set window constraints.\n")
                    end

                    color = color_2
                else
                    if not allegro5.al_set_window_constraints(display,
                            math.floor(DISPLAY_W / 2), math.floor(DISPLAY_H / 2),
                            0, 0)
                    then
                        abort_example("Unable to set window constraints.\n")
                    end

                    color = color_1
                end

                allegro5.al_apply_window_constraints(display, use_constraints)
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_ENTER then
                redraw = true
                use_constraints = not use_constraints
                allegro5.al_apply_window_constraints(display, use_constraints)
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(event.display.source)
            redraw = true
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_EXPOSE then
            redraw = true
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            done = true
        end --[[ switch (event.type) { --]]
    end

    allegro5.al_destroy_font(font)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
