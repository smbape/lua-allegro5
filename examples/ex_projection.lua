#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_projection.c
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

--[[ How far has the text been scrolled. --]]
local scroll_y = 0

--[[ Total length of the scrolling text in pixels. --]]
local text_length = 0

--[[ The Alex logo. --]]
local logo

--[[ The star particle. --]]
local particle

--[[ The font we use for everything. --]]
local font


--[[ Local pseudo-random number generator. --]]
local function rnd(seed)
    local MAX_INT = 0X7FFFFFFF

    seed = ((seed + 1) * 1103515245 + 12345) % MAX_INT
    return bit.band(bit.rshift(seed, 16), 0XFFFF), seed
end


--[[ Load a bitmap or font and exit with a message if it's missing. --]]
local function _load(path, _type, ...)
    local data = nil
    if _type == "bitmap" then
        data = allegro5.al_load_bitmap(path)
    elseif _type == "font" then
        local args = {n=select("#", ...), ...}
        local size = args[1]
        local flags = args[2]
        data = allegro5.al_load_font(path, size, flags)
    end
    if not data then
        abort_example("Could not load %s %s", _type, path)
    end
    return data
end


--[[ Print fading text. --]]
local function _print(font, x, y, r, g, b, fade, text)
    local c = 1 + (y - fade) / 360 / 2.0
    if c > 1 then
        c = 1
    end
    if c < 0 then
        c = 0
    end
    allegro5.al_draw_text(font, allegro5.al_map_rgba_f(c * r, c * g, c * b, c), x, y,
        allegro5.ALLEGRO_ALIGN_CENTER, text)
    return y + allegro5.al_get_font_line_height(font)
end


--[[ Set up a perspective transform. We make the screen span
 - 180 vertical units with square pixel aspect and 90° vertical
 - FoV.
 --]]
local function setup_3d_projection(projection)
    local display = allegro5.al_get_current_display()
    local dw = allegro5.al_get_display_width(display)
    local dh = allegro5.al_get_display_height(display)
    allegro5.al_perspective_transform(projection, -180 * dw / dh, -180, 180,
        180 * dw / dh, 180, 3000)
    allegro5.al_use_projection_transform(projection)
end


--[[ 3D transformations make it very easy to draw a starfield. --]]
local function draw_stars()
    local projection = allegro5.ALLEGRO_TRANSFORM()
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)

    local seed = 0
    local x, y, z
    for i = 0, 100 - INDEX_BASE do
        x, seed = rnd(seed)
        y, seed = rnd(seed)
        z, seed = rnd(seed)

        allegro5.al_identity_transform(projection)
        allegro5.al_translate_transform_3d(projection, 0, 0,
            -2000 + math.floor(scroll_y * 1000 / text_length + z) % 2000 - 180)
        setup_3d_projection(projection)
        allegro5.al_draw_bitmap(particle, x % 4000 - 2000, y % 2000 - 1000, 0)
    end
end


--[[ The main part of this example. --]]
local function draw_scrolling_text()
    local projection = allegro5.ALLEGRO_TRANSFORM()
    local bw = allegro5.al_get_bitmap_width(logo)
    local bh = allegro5.al_get_bitmap_height(logo)
    local x, y, c = 0, 0, 0

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)

    allegro5.al_identity_transform(projection)

    --[[ First, we scroll the text in in the y direction (inside the x/z
    - plane) and move it away from the camera (in the z direction).
    - We move it as far as half the display height to get a vertical
    - FOV of 90 degrees.
    --]]
    allegro5.al_translate_transform_3d(projection, 0, -scroll_y, -180)

    --[[ Then we tilt it backwards 30 degrees. --]]
    allegro5.al_rotate_transform_3d(projection, 1, 0, 0,
        30 * allegro5.ALLEGRO_PI / 180.0)

    --[[ And finally move it down so the 0 position ends up
    - at the bottom of the screen.
    --]]
    allegro5.al_translate_transform_3d(projection, 0, 180, 0)

    setup_3d_projection(projection)

    x = 0
    y = 0
    c = 1 + (y - scroll_y) / 360 / 2.0
    if c < 0 then
        c = 0
    end
    allegro5.al_draw_tinted_bitmap(logo, allegro5.al_map_rgba_f(c, c, c, c),
        x - bw / 2, y, 0)
    y = y + bh

    local function T(str)
        y = _print(font, x, y, 1, 0.9, 0.3, scroll_y, str)
    end

    T("Allegro 5")
    T("")
    T("It is a period of game programming.")
    T("Game coders have won their first")
    T("victory against the evil")
    T("General Protection Fault.")
    T("")
    T("During the battle, hackers managed")
    T("to steal the secret source to the")
    T("General's ultimate weapon,")
    T("the ACCESS VIOLATION, a kernel")
    T("exception with enough power to")
    T("__destroy an entire program.")
    T("")
    T("Pursued by sinister bugs the")
    T("Allegro developers race home")
    T("aboard their library to save")
    T("all game programmers and restore")
    T("freedom to the open source world.")
end

local function draw_intro_text()
    local projection = allegro5.ALLEGRO_TRANSFORM()
    local fade = 0
    local fh = allegro5.al_get_font_line_height(font)

    if scroll_y < 50 then
        fade = (50 - scroll_y) * 12
    else
        fade = (scroll_y - 50) * 4
    end

    allegro5.al_identity_transform(projection)
    allegro5.al_translate_transform_3d(projection, 0, -scroll_y / 3, -181)
    setup_3d_projection(projection)

    _print(font, 0, 0, 0, 0.9, 1, fade, "A long time ago, in a galaxy")
    _print(font, 0, 0 + fh, 0, 0.9, 1, fade, "not too far away...")
end


local function main()
    local redraw = false

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    allegro5.al_init_ttf_addon()
    init_platform_specific()
    allegro5.al_install_keyboard()

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_RESIZABLE)
    local display = allegro5.al_create_display(640, 360)
    if not display then
        abort_example("Error creating display\n")
    end

    allegro5.al_set_new_bitmap_flags(bit.bor(allegro5.ALLEGRO_MIN_LINEAR, bit.bor(allegro5.ALLEGRO_MAG_LINEAR,
        allegro5.ALLEGRO_MIPMAP)))

    font = _load(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf", "font", 40, 0)
    logo = _load(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/alexlogo.png", "bitmap")
    particle = _load(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/air_effect.png", "bitmap")

    allegro5.al_convert_mask_to_alpha(logo, allegro5.al_map_rgb(255, 0, 255))

    text_length = allegro5.al_get_bitmap_height(logo) +
        19 * allegro5.al_get_font_line_height(font)

    local timer = allegro5.al_create_timer(1.0 / 60)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_start_timer(timer)
    while true do
        local event = allegro5.ALLEGRO_EVENT()

        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(display)
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN and
            event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
            break
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            scroll_y = scroll_y + 1
            if scroll_y > text_length * 2 then
                scroll_y = scroll_y - text_length * 2
            end

            redraw = true
        end

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            local black = allegro5.al_map_rgba_f(0, 0, 0, 1)

            allegro5.al_clear_to_color(black)

            draw_stars()

            draw_scrolling_text()

            draw_intro_text()

            allegro5.al_flip_display()
            redraw = false
        end
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
