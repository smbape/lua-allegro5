#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_color_gradient.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local copy = common.copy

local INDEX_BASE = 1 -- lua is 1-based indexed

local ceil = math.ceil

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[         ______   ___    ___
 -        /\  _  \ /\_ \  /\_ \
 -        \ \ \L\ \\--\ \ \--\ \      __     __   _ __   ___
 -         \ \  __ \ \ \ \  \ \ \   /'__`\ /'_ `\/\`'__\/ __`\
 -          \ \ \/\ \ \_\ \_ \_\ \_/\  __--\ \L\ \ \ \--\ \L\ \
 -           \ \_\ \_\/\____\/\____\ \____\ \____ \ \_\\ \____/
 -            \/_/\/_/\/____/\/____/\/____/\/___L\ \/_/ \/___/
 -                                           /\____/
 -                                           \_/__/
 -
 -      Color gradient example program.
 -
 -      This example draws several color gradients, each one linearly
 -      interpolating between two colors. For each version interpolating
 -      the raw R/G/B values there is also versions interpolating the
 -      components in other color spaces (e.g. Oklab L/a/b).
 -
 -      See readme.txt for copyright information.
 --]]


local SCREEN_W = 1280
local SCREEN_H = 720

local ColorSpace = {
    RGB = 1,
    LINEAR = 2,
    HSV = 3,
    OKLAB = 4,
    CIELAB = 5,
}

local colorspace_name = {
    "RGB", "Linear RGB", "HSV", "Oklab", "CIE Lab"
}

local example = {
    font = nil,
    resized = false,
    ox = 0,
    oy = 0,
    scale = 0,
    count = 0,
    colors = {},
}

local function print(x, y, format, ...)
    local s = string.format(format, ...)
    local tw = allegro5.al_get_text_width(example.font, s) / example.scale
    local ox = 0
    if x - tw / 2 < 0 then ox = tw / 2 - x end
    if x + tw / 2 > SCREEN_W then ox = SCREEN_W - x - tw / 2 end
    local backup = copy(allegro5.ALLEGRO_TRANSFORM, allegro5.al_get_current_transform())
    local t = allegro5.ALLEGRO_TRANSFORM()
    -- Since we re-load the font when the window is resized we need to
    -- un-scale it for drawing (but keep the scaled position).
    allegro5.al_identity_transform(t)
    allegro5.al_scale_transform(t, 1 / example.scale, 1 / example.scale)
    allegro5.al_translate_transform(t, x, y)
    allegro5.al_compose_transform(t, backup)
    allegro5.al_use_transform(t)
    -- black "outline" (not really, just offset by 1 pixel but good enough)
    allegro5.al_draw_text(example.font, allegro5.al_map_rgba_f(0, 0, 0, .5), (ox - tw / 2) * example.scale + 1, 1, 0, s)
    allegro5.al_draw_text(example.font, allegro5.al_map_rgb_f(1, 1, 1), (ox - tw / 2) * example.scale, 0, 0, s)
    allegro5.al_use_transform(backup)
end


local function get_colorspace_rgb(cs, v)
    if cs == ColorSpace.RGB then
        return allegro5.al_map_rgb_f(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
    end
    if cs == ColorSpace.OKLAB then
        return allegro5.al_color_oklab(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
    end
    if cs == ColorSpace.CIELAB then
        return allegro5.al_color_lab(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
    end
    if cs == ColorSpace.LINEAR then
        return allegro5.al_color_linear(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
    end
    if cs == ColorSpace.HSV then
        return allegro5.al_color_hsv(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
    end
    return allegro5.al_map_rgb(0, 0, 0)
end


local function draw_gradient(x, y, cs, color1, color2)
    local rgb1 = allegro5.al_color_name(example.colors[color1 + INDEX_BASE])
    local rgb2 = allegro5.al_color_name(example.colors[color2 + INDEX_BASE])
    local v1, v2 = {}, {}
    if cs == ColorSpace.RGB then
        v1[0 + INDEX_BASE], v1[1 + INDEX_BASE], v1[2 + INDEX_BASE] = allegro5.al_unmap_rgb_f(rgb1)
        v2[0 + INDEX_BASE], v2[1 + INDEX_BASE], v2[2 + INDEX_BASE] = allegro5.al_unmap_rgb_f(rgb2)
    elseif cs == ColorSpace.OKLAB then
        v1[0 + INDEX_BASE], v1[1 + INDEX_BASE], v1[2 + INDEX_BASE] = allegro5.al_color_rgb_to_oklab(rgb1.r, rgb1.g, rgb1
        .b)
        v2[0 + INDEX_BASE], v2[1 + INDEX_BASE], v2[2 + INDEX_BASE] = allegro5.al_color_rgb_to_oklab(rgb2.r, rgb2.g, rgb2
        .b)
    elseif cs == ColorSpace.CIELAB then
        v1[0 + INDEX_BASE], v1[1 + INDEX_BASE], v1[2 + INDEX_BASE] = allegro5.al_color_rgb_to_lab(rgb1.r, rgb1.g, rgb1.b)
        v2[0 + INDEX_BASE], v2[1 + INDEX_BASE], v2[2 + INDEX_BASE] = allegro5.al_color_rgb_to_lab(rgb2.r, rgb2.g, rgb2.b)
    elseif cs == ColorSpace.LINEAR then
        v1[0 + INDEX_BASE], v1[1 + INDEX_BASE], v1[2 + INDEX_BASE] = allegro5.al_color_rgb_to_linear(rgb1.r, rgb1.g,
            rgb1.b)
        v2[0 + INDEX_BASE], v2[1 + INDEX_BASE], v2[2 + INDEX_BASE] = allegro5.al_color_rgb_to_linear(rgb2.r, rgb2.g,
            rgb2.b)
    elseif cs == ColorSpace.HSV then
        v1[0 + INDEX_BASE], v1[1 + INDEX_BASE], v1[2 + INDEX_BASE] = allegro5.al_color_rgb_to_hsv(rgb1.r, rgb1.g, rgb1.b)
        v2[0 + INDEX_BASE], v2[1 + INDEX_BASE], v2[2 + INDEX_BASE] = allegro5.al_color_rgb_to_hsv(rgb2.r, rgb2.g, rgb2.b)
    end
    local w = ceil(300 * example.scale)
    local ly = 0
    for i = 0, w - INDEX_BASE do
        local p = 1.0 * i / (w - 1)
        local v = {}
        v[0 + INDEX_BASE] = v1[0 + INDEX_BASE] + p * (v2[0 + INDEX_BASE] - v1[0 + INDEX_BASE])
        v[1 + INDEX_BASE] = v1[1 + INDEX_BASE] + p * (v2[1 + INDEX_BASE] - v1[1 + INDEX_BASE])
        v[2 + INDEX_BASE] = v1[2 + INDEX_BASE] + p * (v2[2 + INDEX_BASE] - v1[2 + INDEX_BASE])
        local rgb = get_colorspace_rgb(cs, v)
        local colx = x + 10 + i / example.scale
        allegro5.al_draw_filled_rectangle(colx, y + 10, colx + 1 / example.scale, y + 80, rgb)
        local l, a, b = allegro5.al_color_rgb_to_oklab(rgb.r, rgb.g, rgb.b)
        if i > 0 then
            allegro5.al_draw_line(colx, y + 6 - ly * 50, colx + 1, y + 6 - l * 50, allegro5.al_map_rgb_f(1, 1, 1), 0)
        end
        ly = l
    end
    allegro5.al_draw_rectangle(x + 11, y + 11, x + 311, y + 81, allegro5.al_map_rgb_f(0, 0, 0), 1)
    allegro5.al_draw_rectangle(x + 10, y + 10, x + 310, y + 80, allegro5.al_map_rgb_f(1, 1, 1), 1)
end


local function redraw()
    if example.resized then
        -- We maintain a transformation to scale and offset everything so
        -- a logical resolution of SCREEN_W x SCREEN_H fits into the
        -- actual window (centered if it doesn't completely fit).
        example.resized = false
        local dw = allegro5.al_get_display_width(allegro5.al_get_current_display())
        local dh = allegro5.al_get_display_height(allegro5.al_get_current_display())
        if SCREEN_W * dh / dw < SCREEN_H then
            example.ox = (dw - SCREEN_W * dh / SCREEN_H) / 2
            example.oy = 0
            example.scale = dh / SCREEN_H
        else
            example.ox = 0
            example.oy = (dh - SCREEN_H * dw / SCREEN_W) / 2
            example.scale = dw / SCREEN_W
        end
        -- For best text quality we reload the font for the specific pixel
        -- size whenever the transformation changes.
        example.font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf", 20 * example.scale, 0)
        if not example.font then
            abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf\n")
        end
    end
    local transform = allegro5.ALLEGRO_TRANSFORM()
    allegro5.al_build_transform(transform, example.ox, example.oy,
        example.scale, example.scale, 0)
    allegro5.al_use_transform(transform)
    allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0.5, 0.5, 0.5))

    -- Here is the actual example. Draw interpolated gradients for
    -- various color spaces.
    local cs = { ColorSpace.RGB, ColorSpace.OKLAB, ColorSpace.CIELAB, ColorSpace.LINEAR, ColorSpace.HSV }
    example.count = 0
    print(640, 10, "color gradients interpolated in different color spaces, with luminance curves")
    local y = 20
    for i = 0, 5 - INDEX_BASE do
        for j = 0, 4 - INDEX_BASE do
            print(160 + j * 320, y + 30, colorspace_name[cs[i + INDEX_BASE]])
        end
        draw_gradient(0, y + 50, cs[i + INDEX_BASE], 1, 2)
        draw_gradient(320, y + 50, cs[i + INDEX_BASE], 3, 4)
        draw_gradient(640, y + 50, cs[i + INDEX_BASE], 5, 6)
        draw_gradient(960, y + 50, cs[i + INDEX_BASE], 7, 8)
        y = y + 140
    end
end


local function init()
    example.colors[1 + INDEX_BASE] = "blue";
    example.colors[2 + INDEX_BASE] = "white";
    example.colors[3 + INDEX_BASE] = "blue";
    example.colors[4 + INDEX_BASE] = "gold";
    example.colors[5 + INDEX_BASE] = "red";
    example.colors[6 + INDEX_BASE] = "lime";
    example.colors[7 + INDEX_BASE] = "black";
    example.colors[8 + INDEX_BASE] = "pink";
end


local function main()
    local done = false
    local need_redraw = true

    if not allegro5.al_init() then
        abort_example("Failed to init Allegro.\n")
    end

    allegro5.al_init_font_addon()
    allegro5.al_init_ttf_addon()
    init_platform_specific()
    example.resized = true

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_RESIZABLE)
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLE_BUFFERS, 1, allegro5.ALLEGRO_SUGGEST)
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLES, 16, allegro5.ALLEGRO_SUGGEST)
    local display = allegro5.al_create_display(SCREEN_W, SCREEN_H)
    if not display then
        abort_example("Error creating display.\n")
    end

    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()
    allegro5.al_init_primitives_addon()

    init()

    local timer = allegro5.al_create_timer(1.0 / 5)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    allegro5.al_start_timer(timer)

    while not done do
        local event = allegro5.ALLEGRO_EVENT()

        if need_redraw then
            redraw()
            allegro5.al_flip_display()
            need_redraw = false
        end

        while true do
            allegro5.al_wait_for_event(queue, event)

            if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
                if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                    done = true
                end
            elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
                done = true
            elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
                allegro5.al_acknowledge_resize(display)
                example.resized = true
            elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
                need_redraw = true
            end

            if allegro5.al_is_event_queue_empty(queue) then
                break
            end
        end
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
