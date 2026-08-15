#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_multiwin.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local W = 640
local H = 400

local function main()
    local display = {}
    local event = allegro5.ALLEGRO_EVENT()
    local pictures = {}

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()
    allegro5.al_init_image_addon()

    local events = allegro5.al_create_event_queue()

    allegro5.al_set_new_display_flags(bit.bor(allegro5.ALLEGRO_WINDOWED, allegro5.ALLEGRO_RESIZABLE))

    --[[ Create two windows. --]]
    display[0 + INDEX_BASE] = allegro5.al_create_display(W, H)
    if not display[0 + INDEX_BASE] then
        abort_example("Error creating display\n")
    end
    pictures[0 + INDEX_BASE] = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not pictures[0 + INDEX_BASE] then
        abort_example("failed to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx\n")
    end

    display[1 + INDEX_BASE] = allegro5.al_create_display(W, H)
    if not display[1 + INDEX_BASE] then
        abort_example("Error creating display\n")
    end
    pictures[1 + INDEX_BASE] = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/allegro.pcx")
    if not pictures[1 + INDEX_BASE] then
        abort_example("failed to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/allegro.pcx\n")
    end

    --[[ This is only needed since we want to receive resize events. --]]
    allegro5.al_register_event_source(events, allegro5.al_get_display_event_source(display[0 + INDEX_BASE]))
    allegro5.al_register_event_source(events, allegro5.al_get_display_event_source(display[1 + INDEX_BASE]))
    allegro5.al_register_event_source(events, allegro5.al_get_keyboard_event_source())

    local done = false
    while true do
        --[[ read input --]]
        while not allegro5.al_is_event_queue_empty(events) do
            allegro5.al_get_next_event(events, event)
            if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
                local key = event.keyboard
                if key.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                    done = true
                    break
                end
            end
            if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
                local de = event.display
                allegro5.al_acknowledge_resize(de.source)
            end
            if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_SWITCH_IN then
                log_printf("%s switching in\n", tostring(event.display.source))
            end
            if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_SWITCH_OUT then
                log_printf("%s switching out\n", tostring(event.display.source))
            end
            if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
                for i = 0, 2 - INDEX_BASE do
                    if display[i + INDEX_BASE] == event.display.source then
                        display[i + INDEX_BASE] = 0
                    end
                end
                allegro5.al_destroy_display(event.display.source)
                local not_done = false
                for i = 0, 2 - INDEX_BASE do
                    if display[i + INDEX_BASE] then
                        not_done = true
                        break
                    end
                end

                if not not_done then
                    done = true
                    break
                end
            end
        end

        if done then
            break
        end

        for i = 0, 2 - INDEX_BASE do
            if display[i + INDEX_BASE] then
                local target = allegro5.al_get_backbuffer(display[i + INDEX_BASE])
                local width = allegro5.al_get_bitmap_width(target)
                local height = allegro5.al_get_bitmap_height(target)

                allegro5.al_set_target_bitmap(target)
                allegro5.al_draw_scaled_bitmap(pictures[0 + INDEX_BASE], 0, 0,
                    allegro5.al_get_bitmap_width(pictures[0 + INDEX_BASE]),
                    allegro5.al_get_bitmap_height(pictures[0 + INDEX_BASE]),
                    0, 0,
                    width / 2, height,
                    0)
                allegro5.al_draw_scaled_bitmap(pictures[1 + INDEX_BASE], 0, 0,
                    allegro5.al_get_bitmap_width(pictures[1 + INDEX_BASE]),
                    allegro5.al_get_bitmap_height(pictures[1 + INDEX_BASE]),
                    width / 2, 0,
                    width / 2, height,
                    0)

                allegro5.al_flip_display()
            end
        end

        allegro5.al_rest(0.001)
    end

    allegro5.al_destroy_bitmap(pictures[0 + INDEX_BASE])
    allegro5.al_destroy_bitmap(pictures[1 + INDEX_BASE])
    allegro5.al_destroy_display(display[0 + INDEX_BASE])
    allegro5.al_destroy_display(display[1 + INDEX_BASE])

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
