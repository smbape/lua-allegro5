#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_prim_wrap.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local new_array = common.new_array

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[         ______   ___    ___
 -        /\  _  \ /\_ \  /\_ \
 -        \ \ \L\ \\//\ \ \//\ \      __     __   _ __   ___
 -         \ \  __ \ \ \ \  \ \ \   /'__`\ /'_ `\/\`'__\/ __`\
 -          \ \ \/\ \ \_\ \_ \_\ \_/\  __//\ \L\ \ \ \//\ \L\ \
 -           \ \_\ \_\/\____\/\____\ \____\ \____ \ \_\\ \____/
 -            \/_/\/_/\/____/\/____/\/____/\/___L\ \/_/ \/___/
 -                                           /\____/
 -                                           \_/__/
 -
 -      Bitmap wrapping options.
 -
 -      See readme.txt for copyright information.
 --]]

local PRIM_TYPE = {
    TRIANGLES = 1,
    POINTS = 2,
    LINES = 3,
    NUM_TYPES = 4,
}

local function draw_square(texture, x, y, w, h, prim_type)
    local c = allegro5.al_map_rgb_f(1, 1, 1)

    if prim_type == PRIM_TYPE.TRIANGLES then
        local vtxs, vtxs_ptr = new_array("ALLEGRO_VERTEX", {
            --[[  x       y       z   u        v      c  --]]
            { x,         y,         0., -2 * w, -2 * h, c },
            { x + 5 * w, y,         0., 3 * w,  -2 * h, c },
            { x + 5 * w, y + 5 * h, 0., 3 * w,  3 * h,  c },
            { x,         y + 5 * h, 0., -2 * w, 3 * h,  c },
        })
        allegro5.al_draw_prim(vtxs_ptr, nil, texture, 0, 4, allegro5.ALLEGRO_PRIM_TRIANGLE_FAN)
    elseif prim_type == PRIM_TYPE.POINTS then
        local POINTS_N = 32
        local d = POINTS_N - 1
        local vtxs, vtxs_ptr = new_array("ALLEGRO_VERTEX", POINTS_N * POINTS_N)

        for iy = 0, POINTS_N - INDEX_BASE do
            for ix = 0, POINTS_N - INDEX_BASE do
                local v = vtxs[iy * POINTS_N + ix]
                v.x = x + 5. * w * ix / d
                v.y = y + 5. * h * iy / d
                v.z = 0.
                v.u = -2 * w + 5. * w * ix / d
                v.v = -2 * h + 5. * h * iy / d
                v.color = c
            end
        end

        allegro5.al_draw_prim(vtxs_ptr, nil, texture, 0, POINTS_N * POINTS_N, allegro5.ALLEGRO_PRIM_POINT_LIST)
    elseif prim_type == PRIM_TYPE.LINES then
        local LINES_N = 32
        local d = LINES_N - 1
        local vtxs, vtxs_ptr = new_array("ALLEGRO_VERTEX", 2 * LINES_N * 2)

        for iy = 0, LINES_N - INDEX_BASE do
            for ix = 0, 2 - INDEX_BASE do
                local v = vtxs[ix + 2 * iy]
                v.x = x + 5. * w * ix
                v.y = y + 5. * h * iy / d
                v.z = 0.
                v.u = -2 * w + 5. * w * ix
                v.v = -2 * h + 5. * h * iy / d
                v.color = c
            end
        end
        for iy = 0, 2 - INDEX_BASE do
            for ix = 0, LINES_N - INDEX_BASE do
                local v = vtxs[2 * ix + iy + 2 * LINES_N]
                v.x = x + 5. * w * ix / d
                v.y = y + 5. * h * iy
                v.z = 0.
                v.u = -2 * w + 5. * w * ix / d
                v.v = -2 * h + 5. * h * iy
                v.color = c
            end
        end
        allegro5.al_draw_prim(vtxs_ptr, nil, texture, 0, 4 * LINES_N, allegro5.ALLEGRO_PRIM_LINE_LIST)
    end
end

local function main(argv)
    local argc = #argv

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_install_mouse()
    allegro5.al_install_keyboard()
    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    allegro5.al_init_primitives_addon()
    init_platform_specific()
    local allow_shader = false
    local use_shader = false
    if argc >= 1 and argv[1] == "--shader" then
        allow_shader = true
    end

    if allow_shader then
        allegro5.al_set_new_display_flags(allegro5.ALLEGRO_PROGRAMMABLE_PIPELINE)
    end
    local display = allegro5.al_create_display(1024, 1024)
    if not display then
        abort_example("Error creating display\n")
    end

    local bitmap = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/texture2.tga")
    if not bitmap then
        abort_example("Could not load '" .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/texture2.tga'.\n")
    end

    local wrap_settings = {
        allegro5.ALLEGRO_BITMAP_WRAP_DEFAULT,
        allegro5.ALLEGRO_BITMAP_WRAP_REPEAT,
        allegro5.ALLEGRO_BITMAP_WRAP_CLAMP,
        allegro5.ALLEGRO_BITMAP_WRAP_MIRROR,
    }
    local wrap_names = {
        "DEFAULT",
        "REPEAT",
        "CLAMP",
        "MIRROR",
    }
    local prim_names = {
        "TRIANGLES",
        "POINTS",
        "LINES",
    }

    local bitmaps = {}
    for i = 0, 4 - INDEX_BASE do
        bitmaps[i + INDEX_BASE] = {}
        for j = 0, 4 - INDEX_BASE do
            allegro5.al_set_new_bitmap_wrap(wrap_settings[i + INDEX_BASE], wrap_settings[j + INDEX_BASE])
            bitmaps[i + INDEX_BASE][j + INDEX_BASE] = allegro5.al_clone_bitmap(bitmap)
        end
    end

    local font = allegro5.al_create_builtin_font()

    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    local memory_buffer = allegro5.al_create_bitmap(allegro5.al_get_display_width(display),
        allegro5.al_get_display_height(display))
    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_VIDEO_BITMAP)
    local display_buffer = allegro5.al_get_backbuffer(display)

    local shader = nil

    if allow_shader then
        shader = allegro5.al_create_shader(allegro5.ALLEGRO_SHADER_AUTO)
        if not shader then
            abort_example("Error creating shader.\n")
        end

        local pixel_file
        if allegro5.al_get_shader_platform(shader) == allegro5.ALLEGRO_SHADER_GLSL then
            if allegro5.ALLEGRO_CFG_SHADER_GLSL then
                pixel_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_prim_wrap_pixel.glsl"
            end
        else
            if allegro5.ALLEGRO_CFG_SHADER_HLSL then
                pixel_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_prim_wrap_pixel.hlsl"
            end
        end

        if not pixel_file then
            abort_example("No shader source\n")
        end
        if not allegro5.al_attach_shader_source(shader, allegro5.ALLEGRO_VERTEX_SHADER,
                allegro5.al_get_default_shader_source(allegro5.ALLEGRO_SHADER_AUTO, allegro5.ALLEGRO_VERTEX_SHADER)) then
            abort_example("al_attach_shader_source for vertex shader failed: %s\n", allegro5.al_get_shader_log(shader))
        end
        if not allegro5.al_attach_shader_source_file(shader, allegro5.ALLEGRO_PIXEL_SHADER, pixel_file) then
            abort_example("al_attach_shader_source_file for pixel shader failed: %s\n", allegro5.al_get_shader_log(shader))
        end
        if not allegro5.al_build_shader(shader) then
            abort_example("al_build_shader failed: %s\n", allegro5.al_get_shader_log(shader))
        end
    end

    local timer = allegro5.al_create_timer(1.0 / 60)
    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_start_timer(timer)

    local redraw = true
    local software = false
    local prim_type = PRIM_TYPE.TRIANGLES
    local quit = false

    while not quit do
        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                quit = true
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_S then
                software = not software
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_R then
                if allow_shader then
                    use_shader = not use_shader
                end
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_P then
                prim_type = (prim_type + 1 - INDEX_BASE) % (PRIM_TYPE.NUM_TYPES - INDEX_BASE) + INDEX_BASE
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        end

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            redraw = false
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))

            local offt_x = 64
            local offt_y = 64
            local spacing = 16
            local bw = allegro5.al_get_bitmap_width(bitmap)
            local bh = allegro5.al_get_bitmap_height(bitmap)
            local w = spacing + 5 * bw
            local h = spacing + 5 * bh

            if software and not use_shader then
                allegro5.al_set_target_bitmap(memory_buffer)
                allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))
            else
                allegro5.al_set_target_bitmap(display_buffer)
            end

            allegro5.al_draw_textf(font, allegro5.al_map_rgb_f(1., 1., 0.5), 16, 16,
                allegro5.ALLEGRO_ALIGN_LEFT, "(S)oftware: %s",
                (function() if (software and not use_shader) then return "On" else return "Off" end end)())
            allegro5.al_draw_textf(font, allegro5.al_map_rgb_f(1., 1., 0.5), 16, 32,
                allegro5.ALLEGRO_ALIGN_LEFT, "Shade(r) (--shader to enable): %s",
                (function() if use_shader then return "On" else return "Off" end end)())
            allegro5.al_draw_textf(font, allegro5.al_map_rgb_f(1., 1., 0.5), 16, 48,
                allegro5.ALLEGRO_ALIGN_LEFT, "(P)rimitive type: %s", prim_names[prim_type])

            for i = 0, 4 - INDEX_BASE do
                allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1., 0.5, 1.), offt_x + spacing + w * i + w / 2,
                    64, allegro5.ALLEGRO_ALIGN_CENTRE, wrap_names[i + INDEX_BASE])
                for j = 0, 4 - INDEX_BASE do
                    if i == 0 then
                        allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1., 0.5, 1.), 16,
                            offt_y + spacing + h * j + h / 2, allegro5.ALLEGRO_ALIGN_LEFT, wrap_names[j + INDEX_BASE])
                    end
                    if use_shader then
                        allegro5.al_use_shader(shader)
                        -- Note that this part will look different in D3D and OpenGL.
                        -- In GL, the wrapping is attached to textures, so
                        -- when sampling twice from the same texture they must
                        -- share the same wrapping mode. This runs into an
                        -- issue with the primitives addon which attempts to
                        -- change it on the fly. To get consistent behavior,
                        -- use the non-default wrapping mode.
                        allegro5.al_set_shader_sampler("tex2", bitmaps[i + INDEX_BASE][j + INDEX_BASE], 1)
                        draw_square(bitmaps[i + INDEX_BASE][j + INDEX_BASE], offt_x + spacing + w * i,
                            offt_y + spacing + h * j, bw, bh, prim_type)
                        allegro5.al_use_shader(nil)
                    else
                        draw_square(bitmaps[i + INDEX_BASE][j + INDEX_BASE], offt_x + spacing + w * i,
                            offt_y + spacing + h * j, bw, bh, prim_type)
                    end
                end
            end

            if software and not use_shader then
                allegro5.al_set_target_bitmap(display_buffer)
                allegro5.al_draw_bitmap(memory_buffer, 0, 0, 0)
            end

            allegro5.al_flip_display()
        end
    end

    allegro5.al_destroy_bitmap(bitmap)
    allegro5.al_destroy_bitmap(memory_buffer)
    for i = 0, 4 - INDEX_BASE do
        for j = 0, 4 - INDEX_BASE do
            allegro5.al_destroy_bitmap(bitmaps[i + INDEX_BASE][j + INDEX_BASE])
        end
    end
    allegro5.al_destroy_font(font)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
