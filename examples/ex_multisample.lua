#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_multisample.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local abort_example = common.abort_example
local pointer_cast = common.pointer_cast

local INDEX_BASE = 1 -- lua is 1-based indexed

local sin = math.sin
local cos = math.cos

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ This example demonstrates the effect of multi-sampling on primitives and
 - bitmaps.
 -
 -
 - In the window without multi-sampling, the edge of the colored lines will not
 - be anti-aliased - each pixel is either filled completely with the primitive
 - color or not at all.
 -
 - The same is true for bitmaps. They will always be drawn at the nearest
 - full-pixel position. However this is only true for the bitmap outline -
 - when texture filtering is enabled the texture itself will honor the sub-pixel
 - position.
 -
 - Therefore in the case with no multi-sampling but texture-filtering the
 - outer black edge will stutter in one-pixel steps while the inside edge will
 - be filtered and appear smooth.
 -
 -
 - In the multi-sampled version the colored lines will be anti-aliased.
 -
 - Same with the bitmaps. This means the bitmap outlines will always move in
 - smooth sub-pixel steps. However if texture filtering is turned off the
 - texels still are rounded to the next integer position.
 -
 - Therefore in the case where multi-sampling is enabled but texture-filtering
 - is not the outer bitmap edges will move smoothly but the inner will not.
 --]]

local font, font_ms
local bitmap_normal
local bitmap_filter
local bitmap_normal_ms
local bitmap_filter_ms
local bitmap_x = (function()
    local bitmap_x = {}
    for i = 1, 8 do
        bitmap_x[i] = 0
    end
    return bitmap_x
end)()
local bitmap_y = (function()
    local bitmap_y = {}
    for i = 1, 8 do
        bitmap_y[i] = 0
    end
    return bitmap_y
end)()
local bitmap_t = 0


local function create_bitmap()
    local checkers_size = 8
    local bitmap_size = 24

    local bitmap = allegro5.al_create_bitmap(bitmap_size, bitmap_size)
    local locked = allegro5.al_lock_bitmap(bitmap, allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_8888, 0)
    local rgba = pointer_cast("unsigned char", locked.data)
    local p = locked.pitch
    for y = 0, bitmap_size - INDEX_BASE do
        for x = 0, bitmap_size - INDEX_BASE do
            local c = bit.band(math.floor(x / checkers_size) + math.floor(y / checkers_size), 1) * 255
            rgba[y * p + x * 4 + 0] = 0
            rgba[y * p + x * 4 + 1] = 0
            rgba[y * p + x * 4 + 2] = 0
            rgba[y * p + x * 4 + 3] = c
        end
    end
    allegro5.al_unlock_bitmap(bitmap)
    return bitmap
end

local function bitmap_move()
    bitmap_t = bitmap_t + 1
    for i = 0, 8 - INDEX_BASE do
        local a = 2 * allegro5.ALLEGRO_PI * i / 16
        local s = sin((bitmap_t + i * 40) / 180 * allegro5.ALLEGRO_PI)
        s = s * 90
        bitmap_x[i + INDEX_BASE] = 100 + s * cos(a)
        bitmap_y[i + INDEX_BASE] = 100 + s * sin(a)
    end
end

local function draw(bitmap, y, text)
    allegro5.al_draw_text(font_ms, allegro5.al_map_rgb(0, 0, 0), 0, y, 0, text)

    for i = 0, 16 - INDEX_BASE do
        local a = 2 * allegro5.ALLEGRO_PI * i / 16
        local c = allegro5.al_color_hsv(i * 360 / 16, 1, 1)
        allegro5.al_draw_line(150 + cos(a) * 10, y + 100 + sin(a) * 10,
            150 + cos(a) * 90, y + 100 + sin(a) * 90, c, 3)
    end

    for i = 0, 8 - INDEX_BASE do
        local a = 2 * allegro5.ALLEGRO_PI * i / 16
        local s = allegro5.al_get_bitmap_width(bitmap)
        allegro5.al_draw_rotated_bitmap(bitmap, s / 2, s / 2,
            50 + bitmap_x[i + INDEX_BASE], y + bitmap_y[i + INDEX_BASE], a, 0)
    end
end

local function main()
    local quit = false
    local redraw = true

    if not allegro5.al_init() then
        abort_example("Couldn't initialise Allegro.\n")
    end
    allegro5.al_init_primitives_addon()

    allegro5.al_install_keyboard()

    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    local memory = create_bitmap()

    --[[ Create the normal display. --]]
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLE_BUFFERS, 0, allegro5.ALLEGRO_REQUIRE)
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLES, 0, allegro5.ALLEGRO_SUGGEST)
    local display = allegro5.al_create_display(300, 450)
    if not display then
        abort_example("Error creating display\n")
    end
    allegro5.al_set_window_title(display, "Normal")

    --[[ Create bitmaps for the normal display. --]]
    allegro5.al_set_new_bitmap_flags(bit.bor(allegro5.ALLEGRO_MIN_LINEAR, allegro5.ALLEGRO_MAG_LINEAR))
    bitmap_filter = allegro5.al_clone_bitmap(memory)
    allegro5.al_set_new_bitmap_flags(0)
    bitmap_normal = allegro5.al_clone_bitmap(memory)

    font = allegro5.al_create_builtin_font()

    local wx, wy = allegro5.al_get_window_position(display)
    if wx < 160 then
        wx = 160
    end

    --[[ Create the multi-sampling display. --]]
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLE_BUFFERS, 1, allegro5.ALLEGRO_REQUIRE)
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLES, 4, allegro5.ALLEGRO_SUGGEST)
    local ms_display = allegro5.al_create_display(300, 450)
    if not ms_display then
        abort_example("Multisampling not available.\n")
    end
    local title = string.format("Multisampling (%dx)", allegro5.al_get_display_option(
        ms_display, allegro5.ALLEGRO_SAMPLES))
    allegro5.al_set_window_title(ms_display, title)

    --[[ Create bitmaps for the multi-sampling display. --]]
    allegro5.al_set_new_bitmap_flags(bit.bor(allegro5.ALLEGRO_MIN_LINEAR, allegro5.ALLEGRO_MAG_LINEAR))
    bitmap_filter_ms = allegro5.al_clone_bitmap(memory)
    allegro5.al_set_new_bitmap_flags(0)
    bitmap_normal_ms = allegro5.al_clone_bitmap(memory)

    font_ms = allegro5.al_create_builtin_font()

    --[[ Move the windows next to each other, because some window manager
    - would put them on top of each other otherwise.
    --]]
    allegro5.al_set_window_position(display, wx - 160, wy)
    allegro5.al_set_window_position(ms_display, wx + 160, wy)

    local timer = allegro5.al_create_timer(1.0 / 30.0)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(ms_display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_start_timer(timer)
    while not quit do
        local event = allegro5.ALLEGRO_EVENT()

        --[[ Check for ESC key or close button event and quit in either case. --]]
        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            quit = true
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                quit = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            bitmap_move()
            redraw = true
        end


        if redraw and allegro5.al_is_event_queue_empty(queue) then
            --[[ Draw the multi-sampled version into the first window. --]]
            allegro5.al_set_target_backbuffer(ms_display)

            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(1, 1, 1))

            draw(bitmap_filter_ms, 0, "filtered, multi-sample")
            draw(bitmap_normal_ms, 250, "no filter, multi-sample")

            allegro5.al_flip_display()

            --[[ Draw the normal version into the second window. --]]
            allegro5.al_set_target_backbuffer(display)

            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(1, 1, 1))

            draw(bitmap_filter, 0, "filtered")
            draw(bitmap_normal, 250, "no filter")

            allegro5.al_flip_display()

            redraw = false
        end
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
