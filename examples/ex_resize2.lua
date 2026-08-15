#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_resize2.c
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
 -    Resizing the window currently shows broken behaviour.
 --]]

local function main()
    local event = allegro5.ALLEGRO_EVENT()
    local redraw = false
    local halt_drawing = false

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    allegro5.al_install_keyboard()
    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()

    allegro5.al_set_config_value(allegro5.al_get_system_config(), "osx", "allow_live_resize", "false")
    allegro5.al_set_new_display_flags(bit.bor(allegro5.ALLEGRO_RESIZABLE,
        allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS))
    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Unable to set any graphic mode\n")
    end

    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    local bmp = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not bmp then
        abort_example("Unable to load image\n")
    end

    local font = allegro5.al_create_builtin_font()

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())

    redraw = true
    halt_drawing = false
    while true do
        if not halt_drawing and redraw and allegro5.al_is_event_queue_empty(queue) then
            allegro5.al_clear_to_color(allegro5.al_map_rgb(255, 0, 0))
            allegro5.al_draw_scaled_bitmap(bmp,
                0, 0, allegro5.al_get_bitmap_width(bmp), allegro5.al_get_bitmap_height(bmp),
                0, 0, allegro5.al_get_display_width(display), allegro5.al_get_display_height(display),
                0)
            allegro5.al_draw_multiline_text(font, allegro5.al_map_rgb(255, 255, 0), 0, 0, 640,
                allegro5.al_get_font_line_height(font), 0, string.format(
                    "size: %d x %d\n"
                    .. "maximized: %s\n"
                    .. "+ key to maximize\n"
                    .. "- key to un-maximize",
                    allegro5.al_get_display_width(display),
                    allegro5.al_get_display_height(display),
                    (function()
                        if bit.band(allegro5.al_get_display_flags(display), allegro5.ALLEGRO_MAXIMIZED) ~= 0 then
                            return "yes"
                        else
                            return "no"
                        end
                    end)()))

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
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_HALT_DRAWING then
            halt_drawing = true
            allegro5.al_acknowledge_drawing_halt(display)
        end
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESUME_DRAWING then
            halt_drawing = false
            allegro5.al_acknowledge_drawing_resume(display)
        end
        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN and
            event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR and
            event.keyboard.unichar == string.byte('+') then
            allegro5.al_set_display_flag(display, allegro5.ALLEGRO_MAXIMIZED, true)
        end
        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR and
            event.keyboard.unichar == string.byte('-') then
            allegro5.al_set_display_flag(display, allegro5.ALLEGRO_MAXIMIZED, false)
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
