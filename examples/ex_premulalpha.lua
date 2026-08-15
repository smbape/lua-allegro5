#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_premulalpha.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local pointer_cast = common.pointer_cast

local floor = math.floor

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local function main()
    local redraw = true

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    allegro5.al_init_font_addon()

    allegro5.al_install_mouse()
    allegro5.al_install_keyboard()

    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Error creating display\n")
    end

    local font = allegro5.al_create_builtin_font()

    local tex1 = allegro5.al_create_bitmap(8, 8)
    local lock = allegro5.al_lock_bitmap(tex1, allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_8888_LE, allegro5.ALLEGRO_LOCK_WRITEONLY)
    local p = pointer_cast("unsigned char", lock.data)
    for y = 0, 7 do
        local lp = p
        for x = 0, 7 do
            if x == 0 or y == 0 or x == 7 or y == 7 then
                p[0] = 0
                p[1] = 0
                p[2] = 0
                p[3] = 0
            else
                p[0] = 0
                p[1] = 255
                p[2] = 0
                p[3] = 255
            end
            p = p + 4
        end
        p = lp + lock.pitch
    end
    allegro5.al_unlock_bitmap(tex1)

    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MAG_LINEAR)
    local tex2 = allegro5.al_clone_bitmap(tex1)

    local timer = allegro5.al_create_timer(1.0 / 30)
    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_start_timer(timer)

    while 1 do
        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        end

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            local x, y = 8, 60
            local a, t = nil, allegro5.al_get_time()
            local th = allegro5.al_get_font_line_height(font)
            local color = allegro5.al_map_rgb_f(0, 0, 0)
            local color2 = allegro5.al_map_rgb_f(1, 0, 0)
            local color3 = allegro5.al_map_rgb_f(0, 0.5, 0)

            t = t / 10
            a = t - floor(t)
            a = a * 2 * allegro5.ALLEGRO_PI

            redraw = false
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0.5, 0.6, 1))

            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
            allegro5.al_draw_textf(font, color, x, y, 0, "not premultiplied")
            allegro5.al_draw_textf(font, color, x, y + th, 0, "no filtering")
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_INVERSE_ALPHA)
            allegro5.al_draw_scaled_rotated_bitmap(tex1, 4, 4, x + 320, y, 8, 8, a, 0)

            y = y + 120

            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
            allegro5.al_draw_textf(font, color, x, y, 0, "not premultiplied")
            allegro5.al_draw_textf(font, color, x, y + th, 0, "mag linear filtering")
            allegro5.al_draw_textf(font, color2, x + 400, y, 0, "wrong dark border")
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_INVERSE_ALPHA)
            allegro5.al_draw_scaled_rotated_bitmap(tex2, 4, 4, x + 320, y, 8, 8, a, 0)

            y = y + 120

            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
            allegro5.al_draw_textf(font, color, x, y, 0, "premultiplied alpha")
            allegro5.al_draw_textf(font, color, x, y + th, 0, "no filtering")
            allegro5.al_draw_textf(font, color, x + 400, y, 0, "no difference")
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
            allegro5.al_draw_scaled_rotated_bitmap(tex1, 4, 4, x + 320, y, 8, 8, a, 0)

            y = y + 120

            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
            allegro5.al_draw_textf(font, color, x, y, 0, "premultiplied alpha")
            allegro5.al_draw_textf(font, color, x, y + th, 0, "mag linear filtering")
            allegro5.al_draw_textf(font, color3, x + 400, y, 0, "correct color")
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
            allegro5.al_draw_scaled_rotated_bitmap(tex2, 4, 4, x + 320, y, 8, 8, a, 0)

            allegro5.al_flip_display()
        end
    end

    allegro5.al_destroy_font(font)
    allegro5.al_destroy_bitmap(tex1)
    allegro5.al_destroy_bitmap(tex2)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
