#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_keyboard_focus.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 -    Example program for the Allegro library.
 -
 -    This program tests if the ALLEGRO_KEYBOARD_STATE `display' field
 -    is set correctly to the focused display.
 --]]

local display1
local display2

local function redraw(color1, color2)
    allegro5.al_set_target_backbuffer(display1)
    allegro5.al_clear_to_color(color1)
    allegro5.al_flip_display()

    allegro5.al_set_target_backbuffer(display2)
    allegro5.al_clear_to_color(color2)
    allegro5.al_flip_display()
end

local function main()
    local black = allegro5.ALLEGRO_COLOR()
    local red = allegro5.ALLEGRO_COLOR()
    local kbdstate = allegro5.ALLEGRO_KEYBOARD_STATE()

    if not allegro5.al_init() then
        abort_example("Error initialising Allegro.\n")
    end

    if not allegro5.al_install_keyboard() then
        abort_example("Error installing keyboard.\n")
    end

    display1 = allegro5.al_create_display(300, 300)
    display2 = allegro5.al_create_display(300, 300)
    if not display1 or not display2 then
        abort_example("Error creating displays.\n")
    end

    black = allegro5.al_map_rgb(0, 0, 0)
    red = allegro5.al_map_rgb(255, 0, 0)

    while 1 do
        allegro5.al_get_keyboard_state(kbdstate)
        if allegro5.al_key_down(kbdstate, allegro5.ALLEGRO_KEY_ESCAPE) then
            break
        end

        if kbdstate.display == display1 then
            redraw(red, black)
        elseif kbdstate.display == display2 then
            redraw(black, red)
        else
            redraw(black, black)
        end

        allegro5.al_rest(0.1)
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
