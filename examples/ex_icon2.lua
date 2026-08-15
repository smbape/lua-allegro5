#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_icon2.c
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

--[[
 -      Example program for the Allegro library.
 -
 -      Set multiple window icons, a big one and a small one.
 -      The small would would be used for the task bar,
 -      and the big one for the alt-tab popup, for example.
 --]]

local function main()
    local icons = {}

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    allegro5.al_install_keyboard()
    allegro5.al_init_image_addon()
    init_platform_specific()

    --[[ First icon 16x16: Read from file. --]]
    icons[0 + INDEX_BASE] = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/cursor.tga")
    if not icons[0 + INDEX_BASE] then
        abort_example("icons.tga not found\n")
    end

    if pcall(function() return type(allegro5.al_x_set_initial_icon) == "function" end) then
        allegro5.al_x_set_initial_icon(icons[0 + INDEX_BASE])
    end

    local display = allegro5.al_create_display(320, 200)
    if not display then
        abort_example("Error creating display\n")
    end
    allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))
    allegro5.al_flip_display()

    --[[ Second icon 32x32: Create it. --]]
    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    icons[1 + INDEX_BASE] = allegro5.al_create_bitmap(32, 32)
    allegro5.al_set_target_bitmap(icons[1 + INDEX_BASE])
    for v = 0, 32 - INDEX_BASE do
        for u = 0, 32 - INDEX_BASE do
            allegro5.al_put_pixel(u, v, allegro5.al_map_rgb_f(u / 31.0, v / 31.0, 1))
        end
    end
    allegro5.al_set_target_backbuffer(display)

    local icons_array, icons_array_ptr, NUM_ICONS = new_array("ALLEGRO_BITMAP *", icons)
    allegro5.al_set_display_icons(display, NUM_ICONS, icons_array_ptr)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    while true do
        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN and
            event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
    end

    allegro5.al_uninstall_system()

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
