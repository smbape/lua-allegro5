#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_cpu.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ An example showing the use of allegro.al_get_cpu_count() and allegro.al_get_ram_size(). --]]

local INTERVAL = 0.1



local function main()
    local done = false
    local redraw = true

    if not allegro5.al_init() then
        abort_example("Failed to init Allegro.\n")
    end

    allegro5.al_init_font_addon()
    init_platform_specific()


    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Error creating display.\n")
    end

    if not allegro5.al_install_keyboard() then
        abort_example("Error installing keyboard.\n")
    end

    local font = allegro5.al_create_builtin_font()

    local timer = allegro5.al_create_timer(INTERVAL)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    allegro5.al_start_timer(timer)

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)

    while not done do
        local event = allegro5.ALLEGRO_EVENT()

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            allegro5.al_clear_to_color(allegro5.al_map_rgba_f(0, 0, 0, 1.0))
            allegro5.al_draw_text(font, allegro5.al_map_rgba_f(1, 1, 0, 1.0), 16, 16, 0,
                -- in lua < 5.3, there is no integer type, only doubles,
                -- therefore, variadic argument is a double causing it not to be a valid integer type
                -- to workaround that, use lua string.format instead
                string.format("Amount of CPU cores detected: %d.", allegro5.al_get_cpu_count()))
            allegro5.al_draw_text(font, allegro5.al_map_rgba_f(0, 1, 1, 1.0), 16, 32, 0,
                -- in lua < 5.3, there is no integer type, only doubles,
                -- therefore, variadic argument is a double causing it not to be a valid integer type
                -- to workaround that, use lua string.format instead
                string.format("Size of random access memory: %d MiB.", allegro5.al_get_ram_size()))
            allegro5.al_flip_display()
            redraw = false
        end

        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                done = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            done = true
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        end
    end

    allegro5.al_destroy_font(font)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
