#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_mouse_focus.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf
local copy = common.copy

local memset = allegro5_lua.C.memset

local sizeof = function(data)
    return data.__sizeof
end

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")

    memset = ffi.C.memset
    sizeof = ffi.sizeof
end

--[[
 -    Example program for the Allegro library.
 -
 -    This program tests if the ALLEGRO_MOUSE_STATE `display' field
 -    is set correctly.
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
    local mst0 = allegro5.ALLEGRO_MOUSE_STATE()
    local mst = allegro5.ALLEGRO_MOUSE_STATE()
    local kst = allegro5.ALLEGRO_KEYBOARD_STATE()

    if not allegro5.al_init() then
        abort_example("Couldn't initialise Allegro.\n")
    end
    if not allegro5.al_install_mouse() then
        abort_example("Couldn't install mouse.\n")
    end
    if not allegro5.al_install_keyboard() then
        abort_example("Couldn't install keyboard.\n")
    end

    display1 = allegro5.al_create_display(300, 300)
    display2 = allegro5.al_create_display(300, 300)
    if not display1 or not display2 then
        allegro5.al_destroy_display(display1)
        allegro5.al_destroy_display(display2)
        abort_example("Couldn't open displays.\n")
    end

    open_log()
    log_printf("Move the mouse cursor over the displays\n")

    black = allegro5.al_map_rgb(0, 0, 0)
    red = allegro5.al_map_rgb(255, 0, 0)

    memset(mst0, 0, sizeof(mst0))

    while 1 do
        allegro5.al_get_mouse_state(mst)
        if mst.display ~= mst0.display or
            mst.x ~= mst0.x or
            mst.y ~= mst0.y then
            if mst.display == nil then
                log_printf("Outside either display\n")
            elseif mst.display == display1 then
                log_printf("In display 1, x = %d, y = %d\n", mst.x, mst.y)
            elseif mst.display == display2 then
                log_printf("In display 2, x = %d, y = %d\n", mst.x, mst.y)
            else
                log_printf("Unknown display = %p, x = %d, y = %d\n", mst.display,
                    mst.x, mst.y)
            end
            mst0 = copy(allegro5.ALLEGRO_MOUSE_STATE, mst)
        end

        if mst.display == display1 then
            redraw(red, black)
        elseif mst.display == display2 then
            redraw(black, red)
        else
            redraw(black, black)
        end

        allegro5.al_rest(0.1)

        allegro5.al_get_keyboard_state(kst)
        if allegro5.al_key_down(kst, allegro5.ALLEGRO_KEY_ESCAPE) then
            break
        end
    end

    close_log(false)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
