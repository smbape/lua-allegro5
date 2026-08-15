#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_vsync.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ Tests vsync.
 --]]

local vsync, fullscreen, frequency, bar_width = 0, 0, 0, 0

local function option(config, name, v)
    local value = allegro5.al_get_config_value(config, "settings", name)
    if value and value ~= "" then
        v = tonumber(value, 10)
    end
    local str = tostring(v)
    allegro5.al_set_config_value(config, "settings", name, str)
    return v
end

local function display_warning(queue, font)
    local event = allegro5.ALLEGRO_EVENT()
    local display = allegro5.al_get_current_display()
    local x = allegro5.al_get_display_width(display) / 2.0
    local h = allegro5.al_get_font_line_height(font)
    local white = allegro5.al_map_rgb_f(1, 1, 1)

    while true do
        -- Convert from 200 px on 480px high screen to same relative position
        -- gtiven actual display height.
        local y = 5 / 12.0 * allegro5.al_get_display_height(display)
        allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))
        allegro5.al_draw_text(font, white, x, y, allegro5.ALLEGRO_ALIGN_CENTRE,
            "Do not continue if you suffer from photosensitive epilepsy")
        allegro5.al_draw_text(font, white, x, y + 15, allegro5.ALLEGRO_ALIGN_CENTRE,
            "or simply hate sliding bars.")
        allegro5.al_draw_text(font, white, x, y + 40, allegro5.ALLEGRO_ALIGN_CENTRE,
            "Press Escape to quit or Enter to continue.")

        y = y + 100
        allegro5.al_draw_text(font, white, x, y, allegro5.ALLEGRO_ALIGN_CENTRE, "Parameters from ex_vsync.ini:")
        y = y + h
        allegro5.al_draw_text(font, white, x, y, allegro5.ALLEGRO_ALIGN_CENTRE, string.format("vsync: %d", vsync))
        y = y + h
        allegro5.al_draw_text(font, white, x, y, allegro5.ALLEGRO_ALIGN_CENTRE, string.format("fullscreen: %d", fullscreen))
        y = y + h
        allegro5.al_draw_text(font, white, x, y, allegro5.ALLEGRO_ALIGN_CENTRE, string.format("frequency: %d", frequency))
        y = y + h
        allegro5.al_draw_text(font, white, x, y, allegro5.ALLEGRO_ALIGN_CENTRE, string.format("bar width: %d", bar_width))

        allegro5.al_flip_display()

        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                return true
            end
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ENTER then
                return false
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            return true
        end
    end
end

local function main()
    local write = false
    local right = true
    local bar_position = 0
    local step_size = 3

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_init_font_addon()
    allegro5.al_init_primitives_addon()
    allegro5.al_init_image_addon()
    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()

    --[[ Read parameters from ex_vsync.ini. --]]
    local config = allegro5.al_load_config_file("ex_vsync.ini")
    if not config then
        config = allegro5.al_create_config()
        write = true
    end

    --[[ 0 -> Driver chooses.
    - 1 -> Force vsync on.
    - 2 -> Force vsync off.
    --]]
    vsync = option(config, "vsync", 0)

    fullscreen = option(config, "fullscreen", 0)
    frequency = option(config, "frequency", 0)
    bar_width = option(config, "bar_width", 10)

    --[[ Write the file back (so a template is generated on first run). --]]
    if write then
        allegro5.al_save_config_file("ex_vsync.ini", config)
    end
    allegro5.al_destroy_config(config)

    --[[ Vsync 1 means force on, 2 means forced off. --]]
    if vsync then
        allegro5.al_set_new_display_option(allegro5.ALLEGRO_VSYNC, vsync, allegro5.ALLEGRO_SUGGEST)
    end

    --[[ Force fullscreen mode. --]]
    if fullscreen ~= 0 then
        allegro5.al_set_new_display_flags(allegro5.ALLEGRO_FULLSCREEN_WINDOW)
        --[[ Set a monitor frequency. --]]
        if frequency then
            allegro5.al_set_new_display_refresh_rate(frequency)
        end
    end

    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Error creating display.\n")
    end

    local font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/a4_font.tga", 0, 0)
    if not font then
        abort_example("Failed to load a4_font.tga\n")
    end

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    local quit = display_warning(queue, font)
    allegro5.al_flush_event_queue(queue)

    local display_width = allegro5.al_get_display_width(display)
    local display_height = allegro5.al_get_display_height(display)

    while not quit do
        local event = allegro5.ALLEGRO_EVENT()

        --[[ With vsync, this will appear as a bar moving smoothly left to right.
       - Without vsync, it will appear that there are many bars moving left to right.
       - More importantly, if you view it in fullscreen, the slanting of the bar will
       - appear more exaggerated as it is now much taller.
       --]]
        if right then
            bar_position = bar_position + step_size
        else
            bar_position = bar_position - step_size
        end

        if right and bar_position >= display_width - bar_width then
            bar_position = display_width - bar_width
            right = false
        elseif not right and bar_position <= 0 then
            bar_position = 0
            right = true
        end

        allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))
        allegro5.al_draw_filled_rectangle(bar_position, 0, bar_position + bar_width - 1, display_height - 1,
            allegro5.al_map_rgb_f(1., 1., 1.))


        allegro5.al_flip_display()

        while allegro5.al_get_next_event(queue, event) do
            if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
                quit = true
            elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
                if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                    quit = true
                end
            end
        end
        --[[ Let's not go overboard and limit flipping at 1000 Hz. Without
       - this my system locks up and requires a hard reboot :P
       --]]
        --[[
       - Limiting this to 500hz so the bar doesn't move too fast. We're
       - no longer in epilepsy mode (I hope).
       --]]
        allegro5.al_rest(.002)
    end

    allegro5.al_destroy_font(font)
    allegro5.al_destroy_event_queue(queue)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
