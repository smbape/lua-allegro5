#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_mouse.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local NUM_BUTTONS = 3

local function draw_mouse_button(but, down)
    local offset = { 0, 70, 35 }

    local x = 400 + offset[but - 1 + INDEX_BASE]
    local y = 130

    local grey = allegro5.al_map_rgb(0xe0, 0xe0, 0xe0)
    local black = allegro5.al_map_rgb(0, 0, 0)

    allegro5.al_draw_filled_rectangle(x, y, x + 27, y + 42, grey)
    allegro5.al_draw_rectangle(x + 0.5, y + 0.5, x + 26.5, y + 41.5, black, 0)
    if down then
        allegro5.al_draw_filled_rectangle(x + 2, y + 2, x + 25, y + 40, black)
    end
end

local function main()
    local msestate = allegro5.ALLEGRO_MOUSE_STATE()
    local kbdstate = allegro5.ALLEGRO_KEYBOARD_STATE()

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_init_primitives_addon()
    allegro5.al_install_mouse()
    allegro5.al_install_keyboard()
    allegro5.al_init_image_addon()
    init_platform_specific()

    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Error creating display\n")
    end

    allegro5.al_hide_mouse_cursor(display)

    local cursor = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/cursor.tga")
    if not cursor then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/cursor.tga\n")
    end

    repeat
        allegro5.al_get_mouse_state(msestate)
        allegro5.al_get_keyboard_state(kbdstate)

        allegro5.al_clear_to_color(allegro5.al_map_rgb(0xff, 0xff, 0xc0))
        for i = 1, NUM_BUTTONS do
            draw_mouse_button(i, allegro5.al_mouse_button_down(msestate, i))
        end
        allegro5.al_draw_bitmap(cursor, msestate.x, msestate.y, 0)
        allegro5.al_flip_display()

        allegro5.al_rest(0.005)
    until allegro5.al_key_down(kbdstate, allegro5.ALLEGRO_KEY_ESCAPE)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
