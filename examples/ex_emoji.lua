#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_emoji.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local copy = common.copy
local rand = common.rand

local INDEX_BASE = 1 -- lua is 1-based indexed

local sin = math.sin

local c_string = allegro5_lua.std.string

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    c_string = ffi.string
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
 -      Emoji example program.
 -
 -      This example draws some emoji characters.
 -
 -      See readme.txt for copyright information.
 --]]

local SCREEN_W = 1280
local SCREEN_H = 720

local emoji = "🐃🐅🐆🐈🐊🐏🐐🐑🐒🐖🐕🐘🐫🐠🐢🐧🐟🐙🦖🕊️🦒🦌"

local example = {
    font1 = nil,
    font2 = nil,
    resized = false,
    ox = 0,
    oy = 0,
    scale = 0,
}

local function Emoji()
    return {
        text = nil,
        font = 0,
        x = 0,
        y = 0,
        ox = 0,
        oy = 0,
        w = 0,
        h = 0,
        dx = 0,
        dy = 0,
        next = nil,
    }
end

local first

local function print(f, x, y, format, ...)
    local scale = 1.0
    local font = example.font1
    if f == 2 then
        font = example.font2
        scale = example.scale
    end
    local s = string.format(format, ...)
    local backup = copy(allegro5.ALLEGRO_TRANSFORM, allegro5.al_get_current_transform())
    local t = allegro5.ALLEGRO_TRANSFORM()
    -- Since we re-load the font when the window is resized we need to
    -- un-scale it for drawing (but keep the scaled position).
    allegro5.al_identity_transform(t)
    allegro5.al_scale_transform(t, scale / example.scale, scale / example.scale)
    allegro5.al_translate_transform(t, x, y)
    allegro5.al_compose_transform(t, backup)
    allegro5.al_use_transform(t)
    -- black "outline" (not really, just offset by 1/1 pixel but good enough)
    allegro5.al_draw_text(font, allegro5.al_map_rgba_f(0, 0, 0, .5), example.scale, example.scale,
        allegro5.ALLEGRO_ALIGN_INTEGER, s)
    allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1, 1, 1), 0, 0, allegro5.ALLEGRO_ALIGN_INTEGER, s)
    allegro5.al_use_transform(backup)
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
        allegro5.al_destroy_font(example.font1)
        example.font1 = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf", 140 * example.scale, 0)
    end
    local transform = allegro5.ALLEGRO_TRANSFORM()
    allegro5.al_build_transform(transform, example.ox, example.oy,
        example.scale, example.scale, 0)
    allegro5.al_use_transform(transform)
    allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0.5, 0.5, 0.5))

    -- Here is the actual example.

    local e = first
    while e do
        print(e.font, e.x - e.ox, e.y - e.oy, e.text)
        e = e.next
    end

    allegro5.al_draw_rectangle(0, 0, SCREEN_W, SCREEN_H, allegro5.al_color_name("silver"), 2)
end


local function collides(e)
    if e.font == 1 then
        return false
    end
    local e2 = first
    while e2 do
        if e2 ~= e and e2.font ~= 1 then
            if e.x < e2.x + e2.w and
                e.y < e2.y + e2.h and
                e.x + e.w > e2.x and
                e.y + e.h > e2.y then
                return true
            end
        end
        e2 = e2.next
    end
    return false
end


local function add_emoji(font, border, text)
    local e = Emoji()
    e.font = font
    e.text = c_string(text)
    local f = example.font1
    if font == 2 then
        f = example.font2
    end
    allegro5.al_get_text_dimensions(f, e.text, e.ox, e.oy, e.w, e.h)
    e.w = e.w - border * 2
    e.h = e.h - border * 2
    e.ox = e.ox + border
    e.oy = e.oy + border
    for t = 0, 1000 - INDEX_BASE do
        e.x = rand() % (SCREEN_W - e.w)
        e.y = rand() % (SCREEN_H - e.h)
        if not collides(e) then
            break
        end
        if e.font == 1 then
            break
        end
    end
    local a = rand() % 360
    e.dx = -2 - rand() % 3
    e.dy = sin(a * allegro5.ALLEGRO_PI / 180)
    e.next = first
    first = e
end


local function init()
    example.font2 = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/NotoColorEmoji_Animals.ttf", 0, 0)

    local u = allegro5.al_ustr_new(emoji)
    local n = allegro5.al_ustr_length(u)
    for i = 0, tonumber(n) - INDEX_BASE do
        local offset1 = allegro5.al_ustr_offset(u, i)
        local offset2 = allegro5.al_ustr_offset(u, i + 1)
        local sub = allegro5.al_ustr_dup_substr(u, offset1, offset2)
        add_emoji(2, 50, allegro5.al_cstr(sub))
        allegro5.al_ustr_free(sub)
    end
    allegro5.al_ustr_free(u)

    add_emoji(1, 0, "Allegro")
end


local function tick()
    local e = first
    local s = 5
    while e do
        local oy = e.y
        e.x = e.x + e.dx * s
        e.y = e.y + e.dy * s
        if collides(e) then
            e.dy = -e.dy
            e.y = oy
        end
        if e.x < 0 - e.w then
            e.x = SCREEN_W + e.w
        end
        if e.y < 0 and e.dy < 0 then
            e.dy = -e.dy
        end
        if e.y > SCREEN_H - e.h and e.dy > 0 then
            e.dy = -e.dy
        end
        e = e.next
    end
end


local function main()
    local timer
    local queue
    local display
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
    display = allegro5.al_create_display(SCREEN_W, SCREEN_H)
    if not display then
        abort_example("Error creating display.\n")
    end

    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()
    allegro5.al_init_primitives_addon()

    timer = allegro5.al_create_timer(1.0 / 60)

    queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    redraw()
    init()

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
                tick()
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
