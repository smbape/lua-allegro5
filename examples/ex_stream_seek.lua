#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_stream_seek.c
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
local startswith = common.startswith

local INDEX_BASE = 1 -- lua is 1-based indexed

local c_string = allegro5_lua.std.string

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    c_string = ffi.string
end

--[[
 -    Example program for the Allegro library, by Todd Cope.
 -
 -    Stream seeking.
 --]]

local display
local timer
local queue
local basic_font = nil
local music_stream = nil
local stream_filename = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/welcome.wav"

local slider_pos = 0.0
local loop_start, loop_end = 0, 0
local mouse_button = (function()
    local mouse_button = {}
    for i = 1, 16 do
        mouse_button[i] = false
    end
    return mouse_button
end)()

local exiting = false

local function initialize()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    allegro5.al_init_primitives_addon()
    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    if not allegro5.al_install_keyboard() then
        abort_example("Could not init keyboard!\n")
    end
    if not allegro5.al_install_mouse() then
        abort_example("Could not init mouse!\n")
    end

    allegro5.al_init_acodec_addon()

    if not allegro5.al_install_audio() then
        abort_example("Could not init sound!\n")
    end
    if not allegro5.al_reserve_samples(16) then
        abort_example("Could not set up voice and mixer.\n")
    end

    init_platform_specific()

    display = allegro5.al_create_display(640, 252)
    if not display then
        abort_example("Could not create display!\n")
    end

    basic_font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/font.tga", 0, 0)
    if not basic_font then
        abort_example("Could not load font!\n")
    end
    timer = allegro5.al_create_timer(1.000 / 30)
    if not timer then
        abort_example("Could not init timer!\n")
    end
    queue = allegro5.al_create_event_queue()
    if not queue then
        abort_example("Could not create event queue!\n")
    end
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
end

local function logic()
    --[[ calculate the position of the slider --]]
    local w = allegro5.al_get_display_width(display) - 20
    local pos = allegro5.al_get_audio_stream_position_secs(music_stream)
    local len = allegro5.al_get_audio_stream_length_secs(music_stream)
    slider_pos = w * (pos / len)
end

local function print_time(x, y, t)
    local hours = math.floor(t / 3600)
    t = t - (hours * 3600)
    local minutes = math.floor(t / 60)
    t = t - (minutes * 60)
    allegro5.al_draw_text(basic_font, allegro5.al_map_rgb(255, 255, 255), x, y, 0,
        string.format("%02d:%02d:%05.2f", hours, minutes, t))
end

local function render()
    local pos = allegro5.al_get_audio_stream_position_secs(music_stream)
    local length = allegro5.al_get_audio_stream_length_secs(music_stream)
    local w = allegro5.al_get_display_width(display) - 20
    local loop_start_pos = w * (loop_start / length)
    local loop_end_pos = w * (loop_end / length)
    local c = allegro5.al_map_rgb(255, 255, 255)

    allegro5.al_clear_to_color(allegro5.al_map_rgb(64, 64, 128))

    local display_name = stream_filename:gsub("\\", "/")
    local current_directory = c_string(allegro5.al_get_current_directory()):gsub("\\", "/")
    if startswith(display_name, env.ALLEGRO_EXAMPLES_DATA_PATH) then
        display_name = "data/" .. display_name:sub(string.len(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/") + 1)
    elseif startswith(display_name, current_directory) then
        display_name = display_name:sub(string.len(current_directory .. "/") + 1)
    end

    --[[ render "music player" --]]
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
    allegro5.al_draw_textf(basic_font, c, 0, 0, 0, "Playing %s", display_name)
    print_time(8, 24, pos)
    allegro5.al_draw_text(basic_font, c, 100, 24, 0, "/")
    print_time(110, 24, length)
    allegro5.al_draw_filled_rectangle(10.0, 48.0 + 7.0, 10.0 + w, 48.0 + 9.0, allegro5.al_map_rgb(0, 0, 0))
    allegro5.al_draw_line(10.0 + loop_start_pos, 46.0, 10.0 + loop_start_pos, 66.0, allegro5.al_map_rgb(0, 168, 128), 0)
    allegro5.al_draw_line(10.0 + loop_end_pos, 46.0, 10.0 + loop_end_pos, 66.0, allegro5.al_map_rgb(255, 0, 0), 0)
    allegro5.al_draw_filled_rectangle(10.0 + slider_pos - 2.0, 48.0, 10.0 + slider_pos + 2.0, 64.0,
        allegro5.al_map_rgb(224, 224, 224))

    --[[ show help --]]
    allegro5.al_draw_text(basic_font, c, 0, 96, 0, "Drag the slider to seek.")
    allegro5.al_draw_text(basic_font, c, 0, 120, 0, "Middle-click to set loop start.")
    allegro5.al_draw_text(basic_font, c, 0, 144, 0, "Right-click to set loop end.")
    allegro5.al_draw_text(basic_font, c, 0, 168, 0, "Left/right arrows to seek.")
    allegro5.al_draw_text(basic_font, c, 0, 192, 0, "Space to pause.")
    allegro5.al_draw_text(basic_font, c, 0, 216, 0, "R to rewind.")

    allegro5.al_flip_display()
end

local function myexit()
    local playing = false
    playing = allegro5.al_get_audio_stream_playing(music_stream)
    if playing and music_stream then
        allegro5.al_drain_audio_stream(music_stream)
    end
    allegro5.al_destroy_audio_stream(music_stream)
end

local function maybe_fiddle_sliders(mx, my)
    local seek_pos = 0
    local w = allegro5.al_get_display_width(display) - 20

    if not (mx >= 10 and mx < 10 + w and my >= 48 and my < 64) then
        return
    end

    seek_pos = allegro5.al_get_audio_stream_length_secs(music_stream) * ((mx - 10) / w)
    if mouse_button[1 + INDEX_BASE] then
        allegro5.al_seek_audio_stream_secs(music_stream, seek_pos)
    elseif mouse_button[2 + INDEX_BASE] then
        if allegro5.al_set_audio_stream_loop_secs(music_stream, loop_start, seek_pos) then
            loop_end = seek_pos
        end
    elseif mouse_button[3 + INDEX_BASE] then
        if allegro5.al_set_audio_stream_loop_secs(music_stream, seek_pos, loop_end) then
            loop_start = seek_pos
        end
    end
end

local function event_handler(event)
    --[[ Was the X button on the window pressed? --]]
    if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
        exiting = true


        --[[ Was a key pressed? --]]
    elseif event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
        if event.keyboard.keycode == allegro5.ALLEGRO_KEY_LEFT then
            local pos = allegro5.al_get_audio_stream_position_secs(music_stream)
            pos = pos - (5.0)
            if pos < 0.0 then
                pos = 0.0
            end
            allegro5.al_seek_audio_stream_secs(music_stream, pos)
        elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_RIGHT then
            local pos = allegro5.al_get_audio_stream_position_secs(music_stream)
            pos = pos + (5.0)
            if not allegro5.al_seek_audio_stream_secs(music_stream, pos) then
                log_printf("seek error!\n")
            end
        elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_R then
            if not allegro5.al_rewind_audio_stream(music_stream) then
                log_printf("rewind error!\n")
            end
        elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
            local playing = false
            playing = allegro5.al_get_audio_stream_playing(music_stream)
            playing = not playing
            allegro5.al_set_audio_stream_playing(music_stream, playing)
        elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
            exiting = true
        end
    elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
        mouse_button[event.mouse.button + INDEX_BASE] = true
        maybe_fiddle_sliders(event.mouse.x, event.mouse.y)
    elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_AXES then
        maybe_fiddle_sliders(event.mouse.x, event.mouse.y)
    elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_UP then
        mouse_button[event.mouse.button + INDEX_BASE] = false
    elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_LEAVE_DISPLAY then
        for i = 1, 16 do
            mouse_button[i] = false;
        end


        --[[ Is it time for the next timer tick? --]]
    elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
        logic()
        render()
    elseif event.type == allegro5.ALLEGRO_EVENT_AUDIO_STREAM_FINISHED then
        log_printf("Stream finished.\n")
    end
end

local function main(argv)
    local argc = #argv

    -- local config
    local event = allegro5.ALLEGRO_EVENT()
    local buffer_count = 0
    local samples = 0
    -- local s
    local playmode = allegro5.ALLEGRO_PLAYMODE_LOOP

    initialize()

    if argc >= 1 then
        stream_filename = argv[1]
    end

    buffer_count = 0
    samples = 0
    local config = allegro5.al_load_config_file("ex_stream_seek.cfg")
    if config then
        local s
        s = allegro5.al_get_config_value(config, "", "buffer_count")
        if s then
            buffer_count = tonumber(s)
        end
        s = allegro5.al_get_config_value(config, "", "samples")
        if s then
            samples = tonumber(s)
        end
        s = allegro5.al_get_config_value(config, "", "playmode")
        if s then
            if s == "loop" then
                playmode = allegro5.ALLEGRO_PLAYMODE_LOOP
            elseif s == "once" then
                playmode = allegro5.ALLEGRO_PLAYMODE_ONCE
            elseif s == "loop_once" then
                playmode = allegro5.ALLEGRO_PLAYMODE_LOOP_ONCE
            end
        end
        allegro5.al_destroy_config(config)
    end
    if buffer_count == 0 then
        buffer_count = 4
    end
    if samples == 0 then
        samples = 1024
    end

    music_stream = allegro5.al_load_audio_stream(stream_filename, buffer_count, samples)
    if not music_stream then
        abort_example("Stream error!\n")
    end
    allegro5.al_register_event_source(queue, allegro5.al_get_audio_stream_event_source(music_stream))

    loop_start = 0.0
    loop_end = allegro5.al_get_audio_stream_length_secs(music_stream)
    allegro5.al_set_audio_stream_loop_secs(music_stream, loop_start, loop_end)

    allegro5.al_set_audio_stream_playmode(music_stream, playmode)
    allegro5.al_attach_audio_stream_to_mixer(music_stream, allegro5.al_get_default_mixer())
    allegro5.al_start_timer(timer)

    while not exiting do
        allegro5.al_wait_for_event(queue, event)
        event_handler(event)
    end

    myexit()
    allegro5.al_destroy_display(display)
    close_log(true)
    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})

--[[ vim: set sts=3 sw=3 et: --]]
