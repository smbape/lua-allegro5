#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_draw.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local pointer_cast = common.pointer_cast
local copy = common.copy

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ Tests some drawing primitives.
 --]]

local ex = {
    font = nil,
    queue = nil,
    background = allegro5.ALLEGRO_COLOR(),
    text = allegro5.ALLEGRO_COLOR(),
    white = allegro5.ALLEGRO_COLOR(),
    foreground = allegro5.ALLEGRO_COLOR(),
    outline = allegro5.ALLEGRO_COLOR(),
    pattern = nil,
    zoom = nil,

    timer = { 0, 0, 0, 0 },
    counter = { 0, 0, 0, 0 },
    FPS = 0,
    text_x = 0,
    text_y = 0,

    software = false,
    samples = 0,
    what = 0,
    thickness = 0,
}

local names = {
    "filled rectangles",
    "rectangles",
    "filled circles",
    "circles",
    "lines"
}

local function draw_pattern(b)
    local w = allegro5.al_get_bitmap_width(b)
    local h = allegro5.al_get_bitmap_height(b)
    local format = allegro5.ALLEGRO_PIXEL_FORMAT_BGR_888
    local light = allegro5.al_map_rgb_f(1, 1, 1)
    local dark = allegro5.al_map_rgb_f(1, 0.9, 0.8)
    local lock
    lock = allegro5.al_lock_bitmap(b, format, allegro5.ALLEGRO_LOCK_WRITEONLY)
    for y = 0, h - INDEX_BASE do
        for x = 0, w - INDEX_BASE do
            local c = (function() if bit.band((x + y), 1) ~= 0 then return light else return dark end end)()
            local data = pointer_cast("unsigned char", lock.data)
            local r, g, b = allegro5.al_unmap_rgb(c)
            data = data + y * lock.pitch
            data = data + x * 3
            data[0] = r
            data[1] = g
            data[2] = b
        end
    end
    allegro5.al_unlock_bitmap(b)
end

local function set_xy(x, y)
    ex.text_x = x
    ex.text_y = y
end

local function print(format, ...)
    local state = allegro5.ALLEGRO_STATE()
    local th = allegro5.al_get_font_line_height(ex.font)
    allegro5.al_store_state(state, allegro5.ALLEGRO_STATE_BLENDER)

    local message = string.format(format, ...)

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
    allegro5.al_draw_textf(ex.font, ex.text, ex.text_x, ex.text_y, 0, "%s", message)
    allegro5.al_restore_state(state)

    ex.text_y = ex.text_y + th
end

local function primitive(l, t, r, b, color, never_fill)
    local cx = (l + r) / 2
    local cy = (t + b) / 2
    local rx = (r - l) / 2
    local ry = (b - t) / 2
    local tk = (function() if never_fill then return 0 else return ex.thickness end end)()
    local w = ex.what
    if w == 0 and never_fill then w = 1 end
    if w == 2 and never_fill then w = 3 end
    if w == 0 then allegro5.al_draw_filled_rectangle(l, t, r, b, color) end
    if w == 1 then allegro5.al_draw_rectangle(l, t, r, b, color, tk) end
    if w == 2 then allegro5.al_draw_filled_ellipse(cx, cy, rx, ry, color) end
    if w == 3 then allegro5.al_draw_ellipse(cx, cy, rx, ry, color, tk) end
    if w == 4 then allegro5.al_draw_line(l, t, r, b, color, tk) end
end

local function draw()
    local x, y
    local w = allegro5.al_get_bitmap_width(ex.zoom)
    local h = allegro5.al_get_bitmap_height(ex.zoom)
    local screen = allegro5.al_get_target_bitmap()
    local mem
    local rects_num = 16
    local rects = {}
    for j = 0, 4 - INDEX_BASE do
        for i = 0, 4 - INDEX_BASE do
            rects[(j * 4 + i) * 4 + 0 + INDEX_BASE] = 2 + i * 0.25 + i * 7
            rects[(j * 4 + i) * 4 + 1 + INDEX_BASE] = 2 + j * 0.25 + j * 7
            rects[(j * 4 + i) * 4 + 2 + INDEX_BASE] = 2 + i * 0.25 + i * 7 + 5
            rects[(j * 4 + i) * 4 + 3 + INDEX_BASE] = 2 + j * 0.25 + j * 7 + 5
        end
    end

    local cx, cy, cw, ch = allegro5.al_get_clipping_rectangle()
    allegro5.al_clear_to_color(ex.background)

    set_xy(8, 0)
    print("Drawing %s (press SPACE to change)", names[ex.what + INDEX_BASE])

    set_xy(8, 16)
    print("Original")

    set_xy(80, 16)
    print("Enlarged x 16")

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)

    if ex.software then
        allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
        allegro5.al_set_new_bitmap_format(allegro5.al_get_bitmap_format(allegro5.al_get_target_bitmap()))
        mem = allegro5.al_create_bitmap(w, h)
        allegro5.al_set_target_bitmap(mem)
        x = 0
        y = 0
    else
        mem = nil
        x = 8
        y = 40
    end
    allegro5.al_draw_bitmap(ex.pattern, x, y, 0)

    --[[ Draw the test scene. --]]

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
    for i = 0, rects_num - INDEX_BASE do
        local rgba = copy(allegro5.ALLEGRO_COLOR, ex.foreground)
        rgba.a = rgba.a * 0.5
        primitive(
            x + rects[i * 4 + 0 + INDEX_BASE],
            y + rects[i * 4 + 1 + INDEX_BASE],
            x + rects[i * 4 + 2 + INDEX_BASE],
            y + rects[i * 4 + 3 + INDEX_BASE],
            rgba, false)
    end

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)

    if ex.software then
        allegro5.al_set_target_bitmap(screen)
        x = 8
        y = 40
        allegro5.al_draw_bitmap(mem, x, y, 0)
        allegro5.al_destroy_bitmap(mem)
    end

    --[[ Grab screen contents into our bitmap. --]]
    allegro5.al_set_target_bitmap(ex.zoom)
    allegro5.al_draw_bitmap_region(screen, x, y, w, h, 0, 0, 0)
    allegro5.al_set_target_bitmap(screen)

    --[[ Draw it enlarged. --]]
    x = 80
    y = 40
    allegro5.al_draw_scaled_bitmap(ex.zoom, 0, 0, w, h, x, y, w * 16, h * 16, 0)

    --[[ Draw outlines. --]]
    for i = 0, rects_num - INDEX_BASE do
        primitive(
            x + rects[i * 4 + 0 + INDEX_BASE] * 16,
            y + rects[i * 4 + 1 + INDEX_BASE] * 16,
            x + rects[i * 4 + 2 + INDEX_BASE] * 16,
            y + rects[i * 4 + 3 + INDEX_BASE] * 16,
            ex.outline, true)
    end

    set_xy(8, 640 - 48)
    print("Thickness: %d (press T to change)", ex.thickness)
    print("Drawing with: %s (press S to change)",
        (function() if ex.software then return "software" else return "hardware" end end)())
    print("Supersampling: %dx (edit ex_draw.ini to change)", ex.samples)

    -- FIXME: doesn't work
    --      al_get_display_option(ALLEGRO_SAMPLE_BUFFERS));
end

local function tick()
    draw()
    allegro5.al_flip_display()
end

local function run()
    local event = allegro5.ALLEGRO_EVENT()
    local need_draw = true

    while true do
        if need_draw and allegro5.al_is_event_queue_empty(ex.queue) then
            tick()
            need_draw = false
        end

        allegro5.al_wait_for_event(ex.queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            return
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                return
            end
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
                ex.what = ex.what + 1
                if ex.what == 5 then
                    ex.what = 0
                end
            end
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_S then
                ex.software = not ex.software
            end
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_T then
                ex.thickness = ex.thickness + 1
                if ex.thickness == 2 then
                    ex.thickness = 0
                end
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            need_draw = true
        end
    end
end

local function init()
    ex.FPS = 60

    ex.font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga", 0, 0)
    if not ex.font then
        abort_example(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga not found.\n")
    end
    ex.background = allegro5.al_color_name("beige")
    ex.foreground = allegro5.al_color_name("black")
    ex.outline = allegro5.al_color_name("red")
    ex.text = allegro5.al_color_name("blue")
    ex.white = allegro5.al_color_name("white")
    ex.pattern = allegro5.al_create_bitmap(32, 32)
    ex.zoom = allegro5.al_create_bitmap(32, 32)
    draw_pattern(ex.pattern)
end

local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_init_primitives_addon()
    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()
    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    init_platform_specific()

    --[[ Read supersampling info from ex_draw.ini. --]]
    ex.samples = 0
    local config = allegro5.al_load_config_file("ex_draw.ini")
    if not config then
        config = allegro5.al_create_config()
    end
    local value = allegro5.al_get_config_value(config, "settings", "samples")
    if value then
        ex.samples = tonumber(value, 10)
    end
    local str = tostring(ex.samples)
    allegro5.al_set_config_value(config, "settings", "samples", str)
    allegro5.al_save_config_file("ex_draw.ini", config)
    allegro5.al_destroy_config(config)

    if ex.samples ~= 0 then
        allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLE_BUFFERS, 1, allegro5.ALLEGRO_REQUIRE)
        allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLES, ex.samples, allegro5.ALLEGRO_SUGGEST)
    end
    local display = allegro5.al_create_display(640, 640)
    if not display then
        abort_example("Unable to create display.\n")
    end

    init()

    local timer = allegro5.al_create_timer(1.0 / ex.FPS)

    ex.queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(ex.queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(ex.queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(ex.queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(ex.queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_start_timer(timer)
    run()

    allegro5.al_destroy_event_queue(ex.queue)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
