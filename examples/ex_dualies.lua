#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_dualies.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local function go()
    local event = allegro5.ALLEGRO_EVENT()

    local modes = 1
    for i = 0, 1 do
        allegro5.al_set_new_display_adapter(i)
        modes = modes * allegro5.al_get_num_display_modes()
    end

    if modes ~= 0 then
        allegro5.al_set_new_display_flags(allegro5.ALLEGRO_FULLSCREEN)
    end

    allegro5.al_set_new_display_adapter(0)
    local d1 = allegro5.al_create_display(640, 480)
    if not d1 then
        abort_example("Error creating first display\n")
    end
    local b1 = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not b1 then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx\n")
    end

    allegro5.al_set_new_display_adapter(1)
    local d2 = allegro5.al_create_display(640, 480)
    if not d2 then
        abort_example("Error creating second display\n")
    end
    local b2 = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/allegro.pcx")
    if not b2 then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/allegro.pcx\n")
    end

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())

    while true do
        if not allegro5.al_is_event_queue_empty(queue) then
            allegro5.al_get_next_event(queue, event)
            if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
                if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                    break
                end
            end
        end

        allegro5.al_set_target_backbuffer(d1)
        allegro5.al_draw_scaled_bitmap(b1, 0, 0, 320, 200, 0, 0, 640, 480, 0)
        allegro5.al_flip_display()

        allegro5.al_set_target_backbuffer(d2)
        allegro5.al_draw_scaled_bitmap(b2, 0, 0, 320, 200, 0, 0, 640, 480, 0)
        allegro5.al_flip_display()

        allegro5.al_rest(0.1)
    end

    allegro5.al_destroy_bitmap(b1)
    allegro5.al_destroy_bitmap(b2)
    allegro5.al_destroy_display(d1)
    allegro5.al_destroy_display(d2)
end

local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_install_keyboard()

    allegro5.al_init_image_addon()

    if allegro5.al_get_num_video_adapters() < 2 then
        abort_example("You need 2 or more adapters/monitors for this example.\n")
    end

    go()

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
