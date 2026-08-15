#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_video.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local SUPPORT_VIDEO = pcall(function() return type(allegro5.al_init_video_addon) == "function" end)
if not SUPPORT_VIDEO then
    local fprintf = function(file, format, ...)
        file:write(string.format(format, ...))
    end
    fprintf(io.stderr, "There is no video support.\n%s\n", allegro5_lua.allegro5.getBuildInformation())
end

local screen
local font
local filename
local zoom = 0

local function video_display(video)
    --[[ Videos often do not use square pixels - these return the scaled dimensions
    - of the video frame.
    --]]
    local scaled_w = allegro5.al_get_video_scaled_width(video)
    local scaled_h = allegro5.al_get_video_scaled_height(video)
    --[[ Get the currently visible frame of the video, based on clock
    - time.
    --]]
    local frame = allegro5.al_get_video_frame(video)
    local w, h = 0, 0
    local tc = allegro5.al_map_rgba_f(0, 0, 0, 0.5)
    local bc = allegro5.al_map_rgba_f(0.5, 0.5, 0.5, 0.5)

    if not frame then
        return
    end

    if zoom == 0 then
        --[[ Always make the video fit into the window. --]]
        h = allegro5.al_get_display_height(screen)
        w = math.floor((h * scaled_w / scaled_h))
        if w > allegro5.al_get_display_width(screen) then
            w = allegro5.al_get_display_width(screen)
            h = math.floor((w * scaled_h / scaled_w))
        end
    else
        w = math.floor(scaled_w)
        h = math.floor(scaled_h)
    end
    local x = (allegro5.al_get_display_width(screen) - w) / 2
    local y = (allegro5.al_get_display_height(screen) - h) / 2

    --[[ Display the frame. --]]
    allegro5.al_draw_scaled_bitmap(frame, 0, 0,
        allegro5.al_get_bitmap_width(frame),
        allegro5.al_get_bitmap_height(frame), x, y, w, h, 0)

    --[[ Show some video information. --]]
    allegro5.al_draw_filled_rounded_rectangle(4, 4,
        allegro5.al_get_display_width(screen) - 4, 4 + 14 * 4, 8, 8, bc)
    local p = allegro5.al_get_video_position(video, allegro5.ALLEGRO_VIDEO_POSITION_ACTUAL)
    allegro5.al_draw_textf(font, tc, 8, 8, 0, "%s", filename)
    allegro5.al_draw_text(font, tc, 8, 8 + 13, 0, string.format("%3d:%02d (V: %+5.2f A: %+5.2f)",
        math.floor(p / 60),
        math.floor(p) % 60,
        allegro5.al_get_video_position(video, allegro5.ALLEGRO_VIDEO_POSITION_VIDEO_DECODE) - p,
        allegro5.al_get_video_position(video, allegro5.ALLEGRO_VIDEO_POSITION_AUDIO_DECODE) - p))
    allegro5.al_draw_text(font, tc, 8, 8 + 13 * 2, 0,
        string.format("video rate %.02f (%dx%d, aspect %.1f) audio rate %.0f",
            allegro5.al_get_video_fps(video),
            allegro5.al_get_bitmap_width(frame),
            allegro5.al_get_bitmap_height(frame),
            scaled_w / scaled_h,
            allegro5.al_get_video_audio_rate(video)))
    allegro5.al_draw_textf(font, tc, 8, 8 + 13 * 3, 0,
        "playing: %s",
        (function() if allegro5.al_is_video_playing(video) then return "true" else return "false" end end)())
    allegro5.al_flip_display()
    allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))
end

local function do_seek(video, incr)
    allegro5.al_seek_video(video, allegro5.al_get_video_position(video, allegro5.ALLEGRO_VIDEO_POSITION_ACTUAL) + incr)
end

local function main(argv)
    local argc = #argv

    local event = allegro5.ALLEGRO_EVENT()
    local fullscreen = false
    local redraw = true
    local use_frame_events = false
    local filename_arg_idx = 1

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    local function done()
        allegro5.al_destroy_display(screen)
        close_log(true)
        if allegro5.al_is_system_installed() then
            allegro5.al_uninstall_system()
        end
    end

    if argc < 1 then
        log_printf("This example needs to be run from the command line.\n"
            .. "Usage: %s [--use-frame-events] <file>\n", argv[0])
        done()
        return
    end

    --[[ If use_frame_events is false, we use a fixed FPS timer. If the video is
    - displayed in a game this probably makes most sense. In a
    - dedicated video player you probably want to listen to
    - ALLEGRO_EVENT_VIDEO_FRAME_SHOW events and only redraw whenever one
    - arrives - to reduce possible jitter and save CPU.
    --]]
    if argc == 2 and argv[1] == "--use-frame-events" then
        use_frame_events = true
        filename_arg_idx = filename_arg_idx + 1
    end

    if not allegro5.al_init_video_addon() then
        abort_example("Could not initialize the video addon.\n")
    end
    allegro5.al_init_font_addon()
    allegro5.al_install_keyboard()

    if not allegro5.al_install_audio() then
        abort_example("Could not init sound!\n")
    end

    allegro5.al_reserve_samples(1)
    allegro5.al_init_primitives_addon()

    local timer = allegro5.al_create_timer(1.0 / 60)

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_RESIZABLE)
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_VSYNC, 1, allegro5.ALLEGRO_SUGGEST)
    screen = allegro5.al_create_display(640, 480)
    if not screen then
        abort_example("Could not set video mode - exiting\n")
    end

    font = allegro5.al_create_builtin_font()
    if not font then
        abort_example("No font.\n")
    end

    allegro5.al_set_new_bitmap_flags(bit.bor(allegro5.ALLEGRO_MIN_LINEAR, allegro5.ALLEGRO_MAG_LINEAR))

    filename = argv[filename_arg_idx]
    local video = allegro5.al_open_video(filename)
    if not video then
        abort_example("Cannot read %s.\n", filename)
    end
    log_printf("video FPS: %f\n", allegro5.al_get_video_fps(video))
    log_printf("video audio rate: %f\n", allegro5.al_get_video_audio_rate(video))
    log_printf(
        "keys:\n"
        .. "Space: Play/Pause\n"
        .. "cursor right/left: seek 10 seconds\n"
        .. "cursor up/down: seek one minute\n"
        .. "F: toggle fullscreen\n"
        .. "1: disable scaling\n"
        .. "S: scale to window\n")

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_video_event_source(video))
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(screen))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())

    allegro5.al_start_video(video, allegro5.al_get_default_mixer())
    allegro5.al_start_timer(timer)

    while true do
        if redraw and allegro5.al_event_queue_is_empty(queue) then
            video_display(video)
            redraw = false
        end

        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
                allegro5.al_set_video_playing(video, not allegro5.al_is_video_playing(video))
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                allegro5.al_close_video(video)
                done()
                return
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_LEFT then
                do_seek(video, -10.0)
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_RIGHT then
                do_seek(video, 10.0)
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_UP then
                do_seek(video, 60.0)
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_DOWN then
                do_seek(video, -60.0)
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_F then
                fullscreen = not fullscreen
                allegro5.al_set_display_flag(screen, allegro5.ALLEGRO_FULLSCREEN_WINDOW,
                    fullscreen)
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_1 then
                zoom = 1
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_S then
                zoom = 0
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(screen)
            allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            --[[
            display_time += 1.0 / 60;
            if (display_time >= video_time) {
               video_time = display_time + video_refresh_timer(is);
            }--]]

            if not use_frame_events then
                redraw = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            allegro5.al_close_video(video)
            done()
            return
        elseif event.type == allegro5.ALLEGRO_EVENT_VIDEO_FRAME_SHOW then
            if use_frame_events then
                redraw = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_VIDEO_FINISHED then
            log_printf("video finished\n")
        end
    end
end

main(rawget(_G, "arg") or {})
