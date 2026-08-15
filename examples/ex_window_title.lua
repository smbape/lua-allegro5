#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_window_title.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ An example showing how to set the title of a window, by Beoran. --]]

local INTERVAL = 1.0


local bmp_x = 200
local bmp_y = 200
local bmp_dx = 96
local bmp_dy = 96
local bmp_flag = 0

local NEW_WINDOW_TITLE = "A Custom Window Title. Press space to start changing it."

local function main()
    local step = 0
    local text
    local title = ""
    local done = false
    local redraw = true

    if not allegro5.al_init() then
        abort_example("Failed to init Allegro.\n")
    end

    if not allegro5.al_init_image_addon() then
        abort_example("Failed to init IIO addon.\n")
    end

    allegro5.al_init_font_addon()
    init_platform_specific()

    text = NEW_WINDOW_TITLE

    allegro5.al_set_new_window_title(NEW_WINDOW_TITLE)

    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Error creating display.\n")
    end

    if not allegro5.al_install_keyboard() then
        abort_example("Error installing keyboard.\n")
    end

    local font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga", 0, 0)
    if not font then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga\n")
    end

    text = allegro5.al_get_new_window_title()

    local timer = allegro5.al_create_timer(INTERVAL)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))


    while not done do
        local event = allegro5.ALLEGRO_EVENT()

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))
            allegro5.al_draw_text(font, allegro5.al_map_rgba_f(1, 1, 1, 0.5), 0, 0, 0, text)
            allegro5.al_flip_display()
            redraw = false
        end

        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                done = true
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
                allegro5.al_start_timer(timer)
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            done = true
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
            step = step + 1
            title = string.format("Title: %d", step)
            text = title
            allegro5.al_set_window_title(display, title)
        end
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
