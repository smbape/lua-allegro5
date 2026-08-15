#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_inject_events.c
--]]

--[[
 - Ryan Roden-Corrent
 - Example that injects regular (non-user-type) allegro events into a queue.
 - This could be useful for 'faking' certain event sources.
 - For example, you could imitate joystick events without a * joystick.
 -
 - Based on the ex_user_events.c example.
 --]]

local assert = require("luassert")
local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local function main()
    local fake_src = allegro5.ALLEGRO_EVENT_SOURCE()
    local fake_keydown_event = allegro5.ALLEGRO_EVENT()
    local fake_joystick_event = allegro5.ALLEGRO_EVENT()
    local event = allegro5.ALLEGRO_EVENT()
    print("fake_src", type(fake_src))

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    --[[ register our 'fake' event source with the queue --]]
    allegro5.al_init_user_event_source(fake_src)
    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, fake_src)

    --[[ fake a joystick event --]]
    fake_joystick_event.any.type = allegro5.ALLEGRO_EVENT_JOYSTICK_AXIS
    fake_joystick_event.joystick.stick = 1
    fake_joystick_event.joystick.axis = 0
    fake_joystick_event.joystick.pos = 0.5
    allegro5.al_emit_user_event(fake_src, fake_joystick_event, nil)

    --[[ fake a keyboard event --]]
    fake_keydown_event.any.type = allegro5.ALLEGRO_EVENT_KEY_DOWN
    fake_keydown_event.keyboard.keycode = allegro5.ALLEGRO_KEY_ENTER
    allegro5.al_emit_user_event(fake_src, fake_keydown_event, nil)

    --[[ poll for the events we injected --]]
    while not allegro5.al_is_event_queue_empty(queue) do
        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            assert.are.equal(event.user.source, fake_src)
            log_printf("Got keydown: %d\n", event.keyboard.keycode)
        elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_AXIS then
            assert.are.equal(event.user.source, fake_src)
            log_printf("Got joystick axis: stick=%d axis=%d pos=%f\n",
                event.joystick.stick, event.joystick.axis, event.joystick.pos)
        else
            abort_example("Unknown event type %d.\n", event.type)
        end
    end

    allegro5.al_destroy_user_event_source(fake_src)
    allegro5.al_destroy_event_queue(queue)

    log_printf("Done.\n")
    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
