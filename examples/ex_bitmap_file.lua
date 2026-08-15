#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_bitmap_file.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local open_log = common.open_log
local init_platform_specific = common.init_platform_specific
local close_log = common.close_log
local log_printf = common.log_printf

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ This example displays a picture on the screen, with support for
 - command-line parameters, multi-screen, screen-orientation and
 - zooming. It is a little different from ex_bitmap in the sense
 - that it uses the allegro.ALLEGRO_FILE interface.
 --]]

local function main(argv)
    local argc = #argv

    local filename
    local bitmap = nil

    local redraw = true
    local zoom = 1

    --[[ The first commandline argument can optionally specify an
     - image to display instead of the default. Allegro's image
     - addon supports BMP, DDS, PCX, TGA and can be compiled with
     - PNG and JPG support on all platforms. Additional formats
     - are supported by platform specific libraries and support for
     - image formats can also be added at runtime.
     --]]
    if argc > 0 and argv[1] ~= "-" then
        filename = argv[1]
    else
        filename = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx"
    end

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    -- Initializes and displays a log window for debugging purposes.
    open_log()

    --[[ The second parameter to the process can optionally specify what
     - adapter to use.
     --]]
    if argc > 1 then
        allegro5.al_set_new_display_adapter(tonumber(argv[2]))
    end

    --[[ Allegro requires installing drivers for all input devices before
     - they can be used.
     --]]
    allegro5.al_install_mouse()
    allegro5.al_install_keyboard()

    --[[ Initialize the image addon. Requires the allegro_image addon
     - library.
     --]]
    allegro5.al_init_image_addon()

    -- Helper functions from common.c.
    init_platform_specific()

    -- Create a new display that we can render the image to.
    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Error creating display\n")
    end

    allegro5.al_set_window_title(display, filename)

    -- Load the image and time how long it took for the log.
    local t0 = allegro5.al_get_time()
    local file = allegro5.al_fopen(filename, "rb")
    if file then
        -- https://rosettacode.org/wiki/Extract_file_extension#Lua
        local fileextension = filename:match("(%.%w+)$") or ""
        bitmap = allegro5.al_load_bitmap_f(file, fileextension)
        allegro5.al_fclose(file)
    end
    local t1 = allegro5.al_get_time()
    if not bitmap then
        abort_example("%s not found or failed to load\n", filename)
    end

    log_printf("Loading took %.4f seconds\n", t1 - t0)

    -- Create a timer that fires 30 times a second.
    local timer = allegro5.al_create_timer(1.0 / 30)
    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_start_timer(timer) -- Start the timer

    -- Primary 'game' loop.
    while true do
        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_wait_for_event(queue, event) -- Wait for and get an event.
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_ORIENTATION then
            local o = event.display.orientation
            if o == allegro5.ALLEGRO_DISPLAY_ORIENTATION_0_DEGREES then
                log_printf("0 degrees\n")
            elseif o == allegro5.ALLEGRO_DISPLAY_ORIENTATION_90_DEGREES then
                log_printf("90 degrees\n")
            elseif o == allegro5.ALLEGRO_DISPLAY_ORIENTATION_180_DEGREES then
                log_printf("180 degrees\n")
            elseif o == allegro5.ALLEGRO_DISPLAY_ORIENTATION_270_DEGREES then
                log_printf("270 degrees\n")
            elseif o == allegro5.ALLEGRO_DISPLAY_ORIENTATION_FACE_UP then
                log_printf("Face up\n")
            elseif o == allegro5.ALLEGRO_DISPLAY_ORIENTATION_FACE_DOWN then
                log_printf("Face down\n")
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
        --[[ Use keyboard to zoom image in and out.
         - 1: Reset zoom.
         - +: Zoom in 10%
         - -: Zoom out 10%
         - f: Zoom to width of window
         --]]
        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if (event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE) then
                break -- Break the loop and quite on escape key.
            end
            if event.keyboard.unichar == string.byte('1') then
                zoom = 1
            end
            if event.keyboard.unichar == string.byte('+') then
                zoom = zoom * 1.1
            end
            if event.keyboard.unichar == string.byte('-') then
                zoom = zoom / 1.1
            end
            if event.keyboard.unichar == string.byte('f') then
                zoom = allegro5.al_get_display_width(display) /
                    allegro5.al_get_bitmap_width(bitmap)
            end
        end

        -- Trigger a redraw on the timer event
        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        end

        -- Redraw, but only if the event queue is empty
        if redraw and allegro5.al_is_event_queue_empty(queue) then
            redraw = false
            -- Clear so we don't get trippy artifacts left after zoom.
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))
            if (zoom == 1) then
                allegro5.al_draw_bitmap(bitmap, 0, 0, 0)
            else
                allegro5.al_draw_scaled_rotated_bitmap(
                    bitmap, 0, 0, 0, 0, zoom, zoom, 0, 0)
            end
            allegro5.al_flip_display()
        end
    end

    allegro5.al_destroy_bitmap(bitmap)

    close_log(false)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
