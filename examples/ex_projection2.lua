#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_projection2.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local new_array = common.new_array

local fmod = math.fmod

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local function draw_pyramid(texture, x, y, z, theta)
    local c = allegro5.al_map_rgb_f(1, 1, 1)
    local t = allegro5.ALLEGRO_TRANSFORM()
    local _, vtx = new_array("ALLEGRO_VERTEX", {
        --[[   x   y   z   u   v  c  --]]
        { 0,  1,  0,  0,  64, c },
        { -1, -1, -1, 0,  0,  c },
        { 1,  -1, -1, 64, 64, c },
        { 1,  -1, 1,  64, 0,  c },
        { -1, -1, 1,  64, 64, c },
    })
    local _, indices = new_array("int", {
        0, 1, 2,
        0, 2, 3,
        0, 3, 4,
        0, 4, 1
    })

    allegro5.al_identity_transform(t)
    allegro5.al_rotate_transform_3d(t, 0, 1, 0, theta)
    allegro5.al_translate_transform_3d(t, x, y, z)
    allegro5.al_use_transform(t)
    allegro5.al_draw_indexed_prim(vtx, nil, texture, indices, 12, allegro5.ALLEGRO_PRIM_TRIANGLE_LIST)
end

local function set_perspective_transform(bmp)
    local p = allegro5.ALLEGRO_TRANSFORM()
    local aspect_ratio = allegro5.al_get_bitmap_height(bmp) / allegro5.al_get_bitmap_width(bmp)
    allegro5.al_set_target_bitmap(bmp)
    allegro5.al_identity_transform(p)
    allegro5.al_perspective_transform(p, -1, aspect_ratio, 1, 1, -aspect_ratio, 1000)
    allegro5.al_use_projection_transform(p)
end

local function main(argv)
    local argc = #argv

    local redraw = false
    local quit = false
    local fullscreen = false
    local background = false
    local display_flags = allegro5.ALLEGRO_RESIZABLE
    local theta = 0

    if argc >= 1 then
        if argv[1] == "--use-shaders" then
            display_flags = bit.bor(display_flags, allegro5.ALLEGRO_PROGRAMMABLE_PIPELINE)
        else
            abort_example("Unknown command line argument: %s\n", argv[1])
        end
    end

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    allegro5.al_init_image_addon()
    allegro5.al_init_primitives_addon()
    allegro5.al_init_font_addon()
    init_platform_specific()
    allegro5.al_install_keyboard()

    allegro5.al_set_new_display_flags(display_flags)
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_DEPTH_SIZE, 16, allegro5.ALLEGRO_SUGGEST)
    --[[ Load everything as a POT bitmap to make sure the projection stuff works
    - with mismatched backing texture and bitmap sizes. --]]
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SUPPORT_NPOT_BITMAP, 0, allegro5.ALLEGRO_REQUIRE)
    local display = allegro5.al_create_display(800, 600)
    if not display then
        abort_example("Error creating display\n")
    end
    allegro5.al_set_window_constraints(display, 256, 512, 0, 0)
    allegro5.al_apply_window_constraints(display, true)
    set_perspective_transform(allegro5.al_get_backbuffer(display))

    --[[ This bitmap is a sub-bitmap of the display, and has a perspective transformation. --]]
    local display_sub_persp = allegro5.al_create_sub_bitmap(allegro5.al_get_backbuffer(display), 0, 0, 256, 256)
    set_perspective_transform(display_sub_persp)

    --[[ This bitmap is a sub-bitmap of the display, and has a orthographic transformation. --]]
    local display_sub_ortho = allegro5.al_create_sub_bitmap(allegro5.al_get_backbuffer(display), 0, 0, 256, 512)

    --[[ This bitmap has a perspective transformation, purposefully non-POT --]]
    local buffer = allegro5.al_create_bitmap(200, 200)
    set_perspective_transform(buffer)

    local timer = allegro5.al_create_timer(1.0 / 60)
    local font = allegro5.al_create_builtin_font()

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_set_new_bitmap_flags(bit.bor(allegro5.ALLEGRO_MIN_LINEAR, bit.bor(allegro5.ALLEGRO_MAG_LINEAR,
        allegro5.ALLEGRO_MIPMAP)))

    local texture = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bkg.png")
    if not texture then
        abort_example("Could not load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bkg.png")
    end

    allegro5.al_start_timer(timer)
    while not quit do
        local event = allegro5.ALLEGRO_EVENT()

        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            quit = true
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(display)
            set_perspective_transform(allegro5.al_get_backbuffer(display))
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                quit = true
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
                fullscreen = not fullscreen
                allegro5.al_set_display_flag(display, allegro5.ALLEGRO_FULLSCREEN_WINDOW, fullscreen)
                set_perspective_transform(allegro5.al_get_backbuffer(display))
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
            theta = fmod(theta + 0.05, 2 * allegro5.ALLEGRO_PI)
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_HALT_DRAWING then
            background = true
            allegro5.al_acknowledge_drawing_halt(display)
            allegro5.al_stop_timer(timer)
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESUME_DRAWING then
            background = false
            allegro5.al_acknowledge_drawing_resume(display)
            allegro5.al_start_timer(timer)
        end

        if not background and redraw and allegro5.al_is_event_queue_empty(queue) then
            allegro5.al_set_target_backbuffer(display)
            allegro5.al_set_render_state(allegro5.ALLEGRO_DEPTH_TEST, 1)
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))
            allegro5.al_clear_depth_buffer(1000)
            draw_pyramid(texture, 0, 0, -4, theta)

            allegro5.al_set_target_bitmap(buffer)
            allegro5.al_set_render_state(allegro5.ALLEGRO_DEPTH_TEST, 1)
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0.1, 0.1))
            allegro5.al_clear_depth_buffer(1000)
            draw_pyramid(texture, 0, 0, -4, theta)

            allegro5.al_set_target_bitmap(display_sub_persp)
            allegro5.al_set_render_state(allegro5.ALLEGRO_DEPTH_TEST, 1)
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0.25))
            allegro5.al_clear_depth_buffer(1000)
            draw_pyramid(texture, 0, 0, -4, theta)

            allegro5.al_set_target_bitmap(display_sub_ortho)
            allegro5.al_set_render_state(allegro5.ALLEGRO_DEPTH_TEST, 0)
            allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1, 1, 1), 128, 16, allegro5.ALLEGRO_ALIGN_CENTER,
                "Press Space to toggle fullscreen")
            allegro5.al_draw_bitmap(buffer, 0, 256, 0)

            allegro5.al_flip_display()
            redraw = false
        end
    end
    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
