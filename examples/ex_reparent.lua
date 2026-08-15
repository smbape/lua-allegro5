#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_reparent.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local FPS = 60

local example = {
    display = nil,
    glyphs = {},
    sub = nil,
    i = 0,
    p = 0,
}


--[[ Draw the parent bitmaps. --]]
local function draw_glyphs()
    local x, y = 0, 0
    allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))
    allegro5.al_draw_bitmap(example.glyphs[0 + INDEX_BASE], 0, 0, 0)
    allegro5.al_draw_bitmap(example.glyphs[1 + INDEX_BASE], 0, 32 * 6, 0)
    if example.p == 1 then
        y = 32 * 6
    end
    x = x + allegro5.al_get_bitmap_x(example.sub)
    y = y + allegro5.al_get_bitmap_y(example.sub)
    allegro5.al_draw_filled_rectangle(x, y,
        x + allegro5.al_get_bitmap_width(example.sub),
        y + allegro5.al_get_bitmap_height(example.sub),
        allegro5.al_map_rgba_f(0.5, 0, 0, 0.5))
end

local function redraw()
    draw_glyphs()

    --[[ Here we draw example.sub, which is never re-created, just
    - re-parented.
    --]]
    for i = 0, 8 do
        allegro5.al_draw_scaled_rotated_bitmap(example.sub, 0, 0,
            i * 100, 32 * 6 + 33 * 5 + 4,
            2.0, 2.0, allegro5.ALLEGRO_PI / 4 * i / 8, 0)
    end
end

local function update()
    --[[ Re-parent out sub bitmap, jumping from glyph to glyph. --]]
    example.i = example.i + 1
    local i = math.floor(example.i / 4) % (16 * 6 + 20 * 5)
    if i < 16 * 6 then
        example.p = 0
        allegro5.al_reparent_bitmap(example.sub, example.glyphs[0 + INDEX_BASE],
            (i % 16) * 32, math.floor(i / 16) * 32, 32, 32)
    else
        example.p = 1
        i = i - 16 * 6
        allegro5.al_reparent_bitmap(example.sub, example.glyphs[1 + INDEX_BASE],
            (i % 20) * 37, math.floor(i / 20) * 33, 37, 33)
    end
end

local function init()
    --[[ We create out sub bitmap once then use it throughout the
    - program, re-parenting as needed.
    --]]
    example.sub = allegro5.al_create_sub_bitmap(example.glyphs[0 + INDEX_BASE], 0, 0, 32, 32)
end

local function main()
    local w, h = 800, 600
    local done = false
    local need_redraw = true

    if not allegro5.al_init() then
        abort_example("Failed to init Allegro.\n")
    end

    if not allegro5.al_init_image_addon() then
        abort_example("Failed to init IIO addon.\n")
    end

    allegro5.al_init_primitives_addon()

    init_platform_specific()

    allegro5.al_set_new_bitmap_flags(bit.bor(allegro5.ALLEGRO_MIN_LINEAR, allegro5.ALLEGRO_MAG_LINEAR))
    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_RESIZABLE)
    example.display = allegro5.al_create_display(w, h)
    if not example.display then
        abort_example("Error creating display.\n")
    end

    if not allegro5.al_install_keyboard() then
        abort_example("Error installing keyboard.\n")
    end

    example.glyphs[0 + INDEX_BASE] = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/font.tga")
    if not example.glyphs[0 + INDEX_BASE] then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/font.tga\n")
    end

    example.glyphs[1 + INDEX_BASE] = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bmpfont.tga")
    if not example.glyphs[1 + INDEX_BASE] then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bmpfont.tga\n")
    end

    init()

    local timer = allegro5.al_create_timer(1.0 / FPS)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())

    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(
        example.display))

    allegro5.al_start_timer(timer)

    while not done do
        local event = allegro5.ALLEGRO_EVENT()
        w = allegro5.al_get_display_width(example.display)
        h = allegro5.al_get_display_height(example.display)

        if need_redraw and allegro5.al_is_event_queue_empty(queue) then
            redraw()
            allegro5.al_flip_display()
            need_redraw = false
        end

        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                done = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            done = true
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(event.display.source)
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            update()
            need_redraw = true
        end
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
