#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_transform.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

local sin = math.sin
local cos = math.cos

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local function main(argv)
    local argc = #argv

    local filename
    local transform = allegro5.ALLEGRO_TRANSFORM()
    local software = false
    local redraw = false
    local blend = false
    local use_subbitmap = true

    if argc >= 1 then
        filename = argv[1]
    else
        filename = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx"
    end

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_init_primitives_addon()
    allegro5.al_install_mouse()
    allegro5.al_install_keyboard()

    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    init_platform_specific()

    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Error creating display\n")
    end

    local subbitmap = allegro5.al_create_sub_bitmap(allegro5.al_get_backbuffer(display), 50, 50, 640 - 50, 480 - 50)
    local overlay = allegro5.al_create_sub_bitmap(allegro5.al_get_backbuffer(display), 100, 100, 300, 50)

    allegro5.al_set_window_title(display, filename)

    local bitmap = allegro5.al_load_bitmap(filename)
    if not bitmap then
        abort_example("%s not found or failed to load\n", filename)
    end
    local font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bmpfont.tga", 0, 0)
    if not font then
        abort_example(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bmpfont.tga not found or failed to load\n")
    end

    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    local buffer = allegro5.al_create_bitmap(640, 480)
    local buffer_subbitmap = allegro5.al_create_sub_bitmap(buffer, 50, 50, 640 - 50, 480 - 50)

    local soft_font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bmpfont.tga", 0, 0)
    if not soft_font then
        abort_example(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bmpfont.tga not found or failed to load\n")
    end

    local timer = allegro5.al_create_timer(1.0 / 60)
    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_start_timer(timer)

    local w = allegro5.al_get_bitmap_width(bitmap)
    local h = allegro5.al_get_bitmap_height(bitmap)

    allegro5.al_set_target_bitmap(overlay)
    allegro5.al_identity_transform(transform)
    allegro5.al_rotate_transform(transform, -0.06)
    allegro5.al_use_transform(transform)

    while 1 do
        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_S then
                software = not software
                if software then
                    --[[ Restore identity transform on display bitmap. --]]
                    local identity = allegro5.ALLEGRO_TRANSFORM()
                    allegro5.al_identity_transform(identity)
                    allegro5.al_use_transform(identity)
                end
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_L then
                blend = not blend
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_B then
                use_subbitmap = not use_subbitmap
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        end

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            local t = 3.0 + allegro5.al_get_time()
            local tint = allegro5.ALLEGRO_COLOR()
            redraw = false

            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
            if blend then
                tint = allegro5.al_map_rgba_f(0.5, 0.5, 0.5, 0.5)
            else
                tint = allegro5.al_map_rgba_f(1, 1, 1, 1)
            end

            if software then
                if use_subbitmap then
                    allegro5.al_set_target_bitmap(buffer)
                    allegro5.al_clear_to_color(allegro5.al_map_rgb_f(1, 0, 0))
                    allegro5.al_set_target_bitmap(buffer_subbitmap)
                else
                    allegro5.al_set_target_bitmap(buffer)
                end
            else
                if use_subbitmap then
                    allegro5.al_set_target_backbuffer(display)
                    allegro5.al_clear_to_color(allegro5.al_map_rgb_f(1, 0, 0))
                    allegro5.al_set_target_bitmap(subbitmap)
                else
                    allegro5.al_set_target_backbuffer(display)
                end
            end

            --[[ Set the transformation on the target bitmap. --]]
            allegro5.al_identity_transform(transform)
            allegro5.al_translate_transform(transform, -640 / 2, -480 / 2)
            allegro5.al_scale_transform(transform, 0.15 + sin(t / 5), 0.15 + cos(t / 5))
            allegro5.al_rotate_transform(transform, t / 50)
            allegro5.al_translate_transform(transform, 640 / 2, 480 / 2)
            allegro5.al_use_transform(transform)

            --[[ Draw some stuff --]]
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))
            allegro5.al_draw_tinted_bitmap(bitmap, tint, 0, 0, 0)
            allegro5.al_draw_tinted_scaled_bitmap(bitmap, tint, w / 4, h / 4, w / 2, h / 2, w, 0, w / 2, h / 4, 0); --ALLEGRO_FLIP_HORIZONTAL);
            allegro5.al_draw_tinted_bitmap_region(bitmap, tint, w / 4, h / 4, w / 2, h / 2, 0, h,
                allegro5.ALLEGRO_FLIP_VERTICAL)
            allegro5.al_draw_tinted_scaled_rotated_bitmap(bitmap, tint, w / 2, h / 2, w + w / 2, h + h / 2, 0.7, 0.7, 0.3,
                0)
            allegro5.al_draw_pixel(w + w / 2, h + h / 2, allegro5.al_map_rgb_f(0, 1, 0))
            allegro5.al_put_pixel(w + w / 2 + 2, h + h / 2 + 2, allegro5.al_map_rgb_f(0, 1, 1))
            allegro5.al_draw_circle(w, h, 50, allegro5.al_map_rgb_f(1, 0.5, 0), 3)

            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
            if software then
                allegro5.al_draw_text(soft_font, allegro5.al_map_rgba_f(1, 1, 1, 1),
                    640 / 2, 430, allegro5.ALLEGRO_ALIGN_CENTRE, "Software Rendering")
                allegro5.al_set_target_backbuffer(display)
                allegro5.al_draw_bitmap(buffer, 0, 0, 0)
            else
                allegro5.al_draw_text(font, allegro5.al_map_rgba_f(1, 1, 1, 1),
                    640 / 2, 430, allegro5.ALLEGRO_ALIGN_CENTRE, "Hardware Rendering")
            end

            --[[ Each target bitmap has its own transformation matrix, so this
             - overlay is unaffected by the transformations set earlier.
             --]]
            allegro5.al_set_target_bitmap(overlay)
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
            allegro5.al_draw_text(font, allegro5.al_map_rgba_f(1, 1, 0, 1),
                0, 10, allegro5.ALLEGRO_ALIGN_LEFT, "hello!")

            allegro5.al_set_target_backbuffer(display)
            allegro5.al_flip_display()
        end
    end

    allegro5.al_destroy_bitmap(bitmap)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
