#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_expose.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local function main()
    local display
    local bitmap
    local timer
    local queue

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_init_primitives_addon()
    allegro5.al_init_image_addon()
    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()
    init_platform_specific()

    allegro5.al_set_new_display_flags(bit.bor(allegro5.ALLEGRO_RESIZABLE,
        allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS))
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SINGLE_BUFFER, true, allegro5.ALLEGRO_REQUIRE)
    display = allegro5.al_create_display(320, 200)
    if not display then
        abort_example("Error creating display\n")
    end

    bitmap = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not bitmap then
        abort_example(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx not found or failed to load\n")
    end
    allegro5.al_draw_bitmap(bitmap, 0, 0, 0)
    allegro5.al_flip_display()

    timer = allegro5.al_create_timer(0.1)

    queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_start_timer(timer)

    while true do
        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN and
            event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(event.display.source)
        end
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_EXPOSE then
            local x = event.display.x
            local y = event.display.y
            local w = event.display.width
            local h = event.display.height
            --[[ Draw a red rectangle over the damaged area. --]]
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
            allegro5.al_draw_filled_rectangle(x, y, x + w, y + h, allegro5.al_map_rgba_f(1, 0, 0, 1))
            allegro5.al_flip_display()
        end
        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            --[[ Slowly restore the original bitmap. --]]
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_INVERSE_ALPHA)
            for y = 0, allegro5.al_get_display_height(display) - 200, 200 do
                for x = 0, allegro5.al_get_display_width(display) - 320, 320 do
                    allegro5.al_draw_tinted_bitmap(bitmap, allegro5.al_map_rgba_f(1, 1, 1, 0.1), x, y, 0)
                end
            end
            allegro5.al_flip_display()
        end
    end

    allegro5.al_destroy_event_queue(queue)
    allegro5.al_destroy_bitmap(bitmap)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
