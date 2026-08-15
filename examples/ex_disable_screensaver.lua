#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_disable_screensaver.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local abort_example = common.abort_example


if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local function main(argv)
    local argc = #argv

    local event = allegro5.ALLEGRO_EVENT()
    local done = false
    local active = true
    local fullscreen = false

    if argc == 1 then
        if argv[1] == "-fullscreen" then
            fullscreen = true
        end
    end

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_install_keyboard()
    allegro5.al_init_font_addon()

    allegro5.al_set_new_display_flags(bit.bor(allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS,
        ((function() if fullscreen then return allegro5.ALLEGRO_FULLSCREEN else return 0 end end)())))

    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Could not create display.\n")
    end

    local font = allegro5.al_create_builtin_font()
    if not font then
        abort_example("Error creating builtin font\n")
    end

    local events = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(events, allegro5.al_get_keyboard_event_source())
    --[[ For expose events --]]
    allegro5.al_register_event_source(events, allegro5.al_get_display_event_source(display))

    repeat
        allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))
        allegro5.al_draw_textf(font, allegro5.al_map_rgb_f(1, 1, 1), 0, 0, 0,
            "Screen saver: %s", (function() if active then return "Normal" else return "Inhibited" end end)())
        allegro5.al_flip_display()
        allegro5.al_wait_for_event(events, event)

        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                done = true
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
                if allegro5.al_inhibit_screensaver(active) then
                    active = not active
                end
            end
        end
    until done

    allegro5.al_destroy_font(font)
    allegro5.al_destroy_event_queue(events)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
