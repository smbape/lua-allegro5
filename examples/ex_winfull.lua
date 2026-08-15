#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_winfull.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local rand = common.rand

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

-- #include "allegro5/allegro.h"

-- #include "common.c"

local function main()
    local event = allegro5.ALLEGRO_EVENT()

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_install_keyboard()

    if allegro5.al_get_num_video_adapters() < 2 then
        abort_example("This example requires multiple video adapters.\n")
    end

    allegro5.al_set_new_display_adapter(1)
    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_WINDOWED)
    local win = allegro5.al_create_display(640, 480)
    if not win then
        abort_example("Error creating windowed display on adapter 1 "
            .. "(do you have multiple adapters?)\n")
    end

    allegro5.al_set_new_display_adapter(0)
    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_FULLSCREEN)
    local full = allegro5.al_create_display(640, 480)
    if not full then
        abort_example("Error creating fullscreen display on adapter 0\n")
    end

    local events = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(events, allegro5.al_get_keyboard_event_source())

    local done = false
    while not done do
        while not allegro5.al_is_event_queue_empty(events) do
            allegro5.al_get_next_event(events, event)
            if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN and
                event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                done = true
                break
            end
        end

        if done then
            break
        end

        allegro5.al_set_target_backbuffer(full)
        allegro5.al_clear_to_color(allegro5.al_map_rgb(rand() % 255, rand() % 255, rand() % 255))
        allegro5.al_flip_display()

        allegro5.al_set_target_backbuffer(win)
        allegro5.al_clear_to_color(allegro5.al_map_rgb(rand() % 255, rand() % 255, rand() % 255))
        allegro5.al_flip_display()

        allegro5.al_rest(0.5)
    end

    allegro5.al_destroy_event_queue(events)

    allegro5.al_destroy_display(win)
    allegro5.al_destroy_display(full)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
