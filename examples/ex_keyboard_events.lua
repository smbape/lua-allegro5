#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_keyboard_events.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local open_log_monospace = common.open_log_monospace
local close_log = common.close_log
local log_printf = common.log_printf
local new_array = common.new_array

local memset = allegro5_lua.C.memset
local c_string = allegro5_lua.std.string

local sizeof = function(vec)
    return vec:sizeof()
end

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    memset = ffi.C.memset
    sizeof = ffi.sizeof
    c_string = ffi.string
end

--[[
 -    Example program for the Allegro library, by Peter Wang.
 -    Updated by Ryan Dickie.
 -
 -    This program tests keyboard events.
 --]]

local WIDTH = 640
local HEIGHT = 480
local SIZE_LOG = 50


--[[ globals --]]
local event_queue
local display



local function log_key(how, keycode, unichar, modifiers)
    local multibyte_cdata, multibyte = new_array("char", 5)
    memset(multibyte, 0, sizeof(multibyte_cdata))
    local key_name

    allegro5.al_utf8_encode(multibyte,
        (function() if unichar <= 32 then return string.byte(' ') else return unichar end end)())
    key_name = allegro5.al_keycode_to_name(keycode)
    log_printf("%-8s  code=%03d, char='%s' (%4d), modifiers=%08x, [%s]\n",
        how, keycode, c_string(multibyte), unichar, modifiers, key_name)
end



--[[ main_loop:
 -  The main loop of the program.  Here we wait for events to come in from
 -  any one of the event sources and react to each one accordingly.  While
 -  there are no events to react to the program sleeps and consumes very
 -  little CPU time.  See main() to see how the event sources and event queue
 -  are set up.
 --]]
local function main_loop()
    local event = allegro5.ALLEGRO_EVENT()

    log_printf("Focus on the main window (black) and press keys to see events.\n")

    while true do
        --[[ Take the next event out of the event queue, and store it in `event'. --]]
        allegro5.al_wait_for_event(event_queue, event)

        --[[ Check what type of event we got and act accordingly.  ALLEGRO_EVENT
       - is a union type and interpretation of its contents is dependent on
       - the event type, which is given by the 'type' field.
       -
       - Each event also comes from an event source and has a timestamp.
       - These are accessible through the 'any.source' and 'any.timestamp'
       - fields respectively, e.g. 'event.any.timestamp'
       --]]

        --[[ ALLEGRO_EVENT_KEY_DOWN - a keyboard key was pressed.
          --]]
        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            log_key("KEY_DOWN", event.keyboard.keycode, 0, 0)

        --[[ ALLEGRO_EVENT_KEY_UP - a keyboard key was released.
          --]]
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_UP then
            log_key("KEY_UP", event.keyboard.keycode, 0, 0)

        --[[ ALLEGRO_EVENT_KEY_CHAR - a character was typed or repeated.
          --]]
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            local label = (function() if event.keyboard["repeat"] then return "repeat" else return "KEY_CHAR" end end)()
            log_key(label,
                event.keyboard.keycode,
                event.keyboard.unichar,
                event.keyboard.modifiers)

        --[[ ALLEGRO_EVENT_DISPLAY_CLOSE - the window close button was pressed.
          --]]
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            return
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_SWITCH_OUT then
            allegro5.al_clear_keyboard_state(event.display.source)
            log_printf("Cleared keyboard state\n")
            break

        --[[ We received an event of some type we don't know about.
          - Just ignore it.
          --]]
        else
            -- nothing to do
        end
    end
end



local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log_monospace()

    display = allegro5.al_create_display(WIDTH, HEIGHT)
    if not display then
        abort_example("al_create_display failed\n")
    end
    allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))
    allegro5.al_flip_display()

    if not allegro5.al_install_keyboard() then
        abort_example("al_install_keyboard failed\n")
    end

    event_queue = allegro5.al_create_event_queue()
    if not event_queue then
        abort_example("al_create_event_queue failed\n")
    end

    allegro5.al_register_event_source(event_queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(event_queue, allegro5.al_get_display_event_source(display))

    main_loop()

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
