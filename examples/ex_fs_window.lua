#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_fs_window.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local display
local picture
local queue
local font
local big = false

local function redraw()
    local color = allegro5.ALLEGRO_COLOR()
    local w = allegro5.al_get_display_width(display)
    local h = allegro5.al_get_display_height(display)
    local pw = allegro5.al_get_bitmap_width(picture)
    local ph = allegro5.al_get_bitmap_height(picture)
    local th = allegro5.al_get_font_line_height(font)
    local cx = (w - pw) * 0.5
    local cy = (h - ph) * 0.5
    local white = allegro5.al_map_rgb_f(1, 1, 1)

    color = allegro5.al_map_rgb_f(0.8, 0.7, 0.9)
    allegro5.al_clear_to_color(color)

    color = allegro5.al_map_rgb(255, 0, 0)
    allegro5.al_draw_line(0, 0, w, h, color, 0)
    allegro5.al_draw_line(0, h, w, 0, color, 0)

    allegro5.al_draw_bitmap(picture, cx, cy, 0)

    allegro5.al_draw_textf(font, white, w / 2, cy + ph, allegro5.ALLEGRO_ALIGN_CENTRE,
        "Press Space to toggle fullscreen")
    allegro5.al_draw_textf(font, white, w / 2, cy + ph + th, allegro5.ALLEGRO_ALIGN_CENTRE,
        "Press Enter to toggle window size")
    allegro5.al_draw_text(font, white, w / 2, cy + ph + th * 2, allegro5.ALLEGRO_ALIGN_CENTRE,
        string.format("Window: %dx%d (%s)",
            allegro5.al_get_display_width(display), allegro5.al_get_display_height(display),
            (function()
                if (bit.band(allegro5.al_get_display_flags(display), allegro5.ALLEGRO_FULLSCREEN_WINDOW)) then
                    return
                    "fullscreen"
                else
                    return "not fullscreen"
                end
            end)())
    )

    allegro5.al_flip_display()
end

local function run()
    local event = allegro5.ALLEGRO_EVENT()
    local quit = false
    while not quit do
        while allegro5.al_get_next_event(queue, event) do
            if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
                quit = true
            elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
                if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                    quit = true
                elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
                    local opp = bit.band(allegro5.al_get_display_flags(display), allegro5.ALLEGRO_FULLSCREEN_WINDOW) == 0
                    allegro5.al_set_display_flag(display, allegro5.ALLEGRO_FULLSCREEN_WINDOW, opp)
                    redraw()
                elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_ENTER then
                    big = not big
                    if big then
                        allegro5.al_resize_display(display, 800, 600)
                    else
                        allegro5.al_resize_display(display, 640, 480)
                    end
                    redraw()
                end
            end
        end
        --[[ FIXME: Lazy timing --]]
        allegro5.al_rest(0.02)
        redraw()
    end
end

local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_init_primitives_addon()
    allegro5.al_install_keyboard()
    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    init_platform_specific()

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_FULLSCREEN_WINDOW)
    display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Error creating display\n")
    end

    queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    picture = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not picture then
        abort_example("mysha.pcx not found\n")
    end

    font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga", 0, 0)
    if not font then
        abort_example(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga not found.\n")
    end

    redraw()
    run()

    allegro5.al_destroy_display(display)

    allegro5.al_destroy_event_queue(queue)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
