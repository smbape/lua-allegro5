#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_mouse_warp.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf

local memset = allegro5_lua.C.memset

local sizeof = function(data)
    return data.__sizeof
end

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    memset = ffi.C.memset
    sizeof = ffi.sizeof
end

local width = 640
local height = 480

local function main()
    local event = allegro5.ALLEGRO_EVENT()
    local right_button_down = false
    local redraw = true
    local fake_x, fake_y = 0, 0

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    allegro5.al_init_primitives_addon()
    allegro5.al_init_font_addon()
    allegro5.al_install_mouse()
    allegro5.al_install_keyboard()

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_WINDOWED)
    local display = allegro5.al_create_display(width, height)
    if not display then
        abort_example("Could not create display.\n")
    end

    memset(event, 0, sizeof(event))

    local event_queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(event_queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(event_queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(event_queue, allegro5.al_get_keyboard_event_source())

    local font = allegro5.al_create_builtin_font()
    local white = allegro5.al_map_rgb_f(1, 1, 1)

    while 1 do
        if redraw and allegro5.al_is_event_queue_empty(event_queue) then
            local th = allegro5.al_get_font_line_height(font)

            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))

            if right_button_down then
                allegro5.al_draw_line(width / 2, height / 2, fake_x, fake_y,
                    allegro5.al_map_rgb_f(1, 0, 0), 1)
                allegro5.al_draw_line(fake_x - 5, fake_y, fake_x + 5, fake_y,
                    allegro5.al_map_rgb_f(1, 1, 1), 2)
                allegro5.al_draw_line(fake_x, fake_y - 5, fake_x, fake_y + 5,
                    allegro5.al_map_rgb_f(1, 1, 1), 2)
            end

            allegro5.al_draw_text(font, white, 0, 0, 0, string.format("x: %i y: %i dx: %i dy %i",
                event.mouse.x, event.mouse.y,
                event.mouse.dx, event.mouse.dy))
            allegro5.al_draw_textf(font, white, width / 2, height / 2 - th, allegro5.ALLEGRO_ALIGN_CENTRE,
                "Left-Click to warp pointer to the middle once.")
            allegro5.al_draw_textf(font, white, width / 2, height / 2, allegro5.ALLEGRO_ALIGN_CENTRE,
                "Hold right mouse button to constantly move pointer to the middle.")
            allegro5.al_flip_display()
            redraw = false
        end

        allegro5.al_wait_for_event(event_queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_MOUSE_WARPED then
            log_printf("Warp to xy=(%d %d) dxy=(%d %d)\n", event.mouse.x, event.mouse.y,
                event.mouse.dx, event.mouse.dy)
        end
        if event.type == allegro5.ALLEGRO_EVENT_MOUSE_AXES then
            if right_button_down then
                allegro5.al_set_mouse_xy(display, width / 2, height / 2)
                fake_x = fake_x + event.mouse.dx
                fake_y = fake_y + event.mouse.dy
            end
            redraw = true
        end
        if event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
            if event.mouse.button == 1 then
                allegro5.al_set_mouse_xy(display, width / 2, height / 2)
            end
            if event.mouse.button == 2 then
                right_button_down = true
                fake_x = width / 2
                fake_y = height / 2
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_UP then
            if event.mouse.button == 2 then
                right_button_down = false
            end
        end
    end

    allegro5.al_destroy_event_queue(event_queue)
    allegro5.al_destroy_display(display)

    close_log(false)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
