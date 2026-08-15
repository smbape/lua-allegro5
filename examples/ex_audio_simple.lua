#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_audio_simple.c
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
local startswith = common.startswith

local INDEX_BASE = 1 -- lua is 1-based indexed

local sin = math.sin

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 -    Example program for the Allegro library.
 -
 -    Demonstrate 'simple' audio interface.
 --]]

local RESERVED_SAMPLES = 16
local MAX_SAMPLE_DATA = 10

local default_files = { env.ALLEGRO_EXAMPLES_DATA_PATH .. "/welcome.wav",
    env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/fire_0.ogg", env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/fire_1.ogg",
    env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/fire_2.ogg", env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/fire_3.ogg",
    env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/fire_4.ogg", env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/fire_5.ogg",
    env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/fire_6.ogg", env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/fire_7.ogg",
}

local function main(argv)
    local argc = #argv

    local sample_data = {}
    local event = allegro5.ALLEGRO_EVENT()
    local sample_id = allegro5.ALLEGRO_SAMPLE_ID()
    local sample_id_valid = false
    local music
    local panning = false

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    if not allegro5.al_init_font_addon() then
        abort_example("Could not init the font addon.\n")
    end

    open_log()

    if argc < 1 then
        log_printf("This example can be run from the command line.\nUsage: %s {audio_files}\n", argv[0])
        argv = default_files
        argc = #default_files
    end

    allegro5.al_install_keyboard()

    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Could not create display\n")
    end
    local font = allegro5.al_create_builtin_font()

    local timer = allegro5.al_create_timer(1 / 60.0)
    allegro5.al_start_timer(timer)
    local event_queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(event_queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(event_queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(event_queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_init_acodec_addon()

    -- Restart:

    if not allegro5.al_install_audio() then
        abort_example("Could not init sound!\n")
    end

    if not allegro5.al_reserve_samples(RESERVED_SAMPLES) then
        abort_example("Could not set up voice and mixer.\n")
    end

    sample_data = {}

    for i = 1, math.min(argc, MAX_SAMPLE_DATA) do
        local filename = argv[i]

        --[[ Load the entire sound file from disk. --]]
        sample_data[i] = allegro5.al_load_sample(argv[i])
        if not sample_data[i] then
            log_printf("Could not load sample from '%s'!\n", filename)
        end
    end

    log_printf(
        "Press digits to play sounds.\n"
        .. "Space to stop sounds.\n"
        .. "Add Alt to play sounds repeatedly.\n"
        .. "'p' to pan the last played sound.\n"
        .. "Escape to quit.\n")

    while true do
        allegro5.al_wait_for_event(event_queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end
            if event.keyboard.unichar == string.byte(' ') then
                log_printf("Stopping all sounds\n")
                allegro5.al_stop_samples()
                if music then
                    allegro5.al_set_audio_stream_playing(music, false)
                end
            end

            if event.keyboard.keycode >= allegro5.ALLEGRO_KEY_0 and event.keyboard.keycode <= allegro5.ALLEGRO_KEY_9 then
                local loop = bit.band(event.keyboard.modifiers, allegro5.ALLEGRO_KEYMOD_ALT) ~= 0
                local bidir = bit.band(event.keyboard.modifiers, allegro5.ALLEGRO_KEYMOD_CTRL) ~= 0
                local reversed = bit.band(event.keyboard.modifiers, allegro5.ALLEGRO_KEYMOD_SHIFT) ~= 0
                local i = (event.keyboard.keycode - allegro5.ALLEGRO_KEY_0 + 9) % 10 + INDEX_BASE
                if sample_data[i] then
                    local new_sample_id = allegro5.ALLEGRO_SAMPLE_ID()
                    local playmode
                    local playmode_str
                    if loop then
                        playmode = allegro5.ALLEGRO_PLAYMODE_LOOP
                        playmode_str = "on a loop"
                    elseif bidir then
                        playmode = allegro5.ALLEGRO_PLAYMODE_BIDIR
                        playmode_str = "on a bidirectional loop"
                    else
                        playmode = allegro5.ALLEGRO_PLAYMODE_ONCE
                        playmode_str = "once"
                    end
                    local ret = allegro5.al_play_sample(sample_data[i], 1.0, 0.0, 1.0,
                        playmode, new_sample_id)
                    if reversed then
                        local inst = allegro5.al_lock_sample_id(new_sample_id)
                        allegro5.al_set_sample_instance_position(inst, allegro5.al_get_sample_instance_length(inst) - 1)
                        allegro5.al_set_sample_instance_speed(inst, -1)
                        allegro5.al_unlock_sample_id(new_sample_id)
                    end
                    if ret then
                        log_printf("Playing %d %s\n", i, playmode_str)
                    else
                        log_printf(
                            "al_play_sample_data failed, perhaps too many sounds\n")
                    end
                    if not panning then
                        if ret then
                            sample_id = new_sample_id
                            sample_id_valid = true
                        end
                    end
                end
            end

            if event.keyboard.unichar == string.byte('p') then
                if sample_id_valid then
                    panning = not panning
                    if panning then
                        log_printf("Panning\n")
                    else
                        log_printf("Not panning\n")
                    end
                end
            end

            if event.keyboard.unichar == string.byte('m') then
                music = allegro5.al_play_audio_stream(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/../../demos/cosmic_protector/data/sfx/title_music.ogg")
            end

            --[[ Hidden feature: restart audio subsystem.
          - For debugging race conditions on shutting down the audio.
          --]]
            if event.keyboard.unichar == string.byte('r') then
                for i = 1, math.min(argc, MAX_SAMPLE_DATA) do
                    if sample_data[i] then
                        allegro5.al_destroy_sample(sample_data[i])
                    end
                end
                allegro5.al_uninstall_audio()
                -- goto Restart
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            local y = 12
            local dy = 12
            if panning and sample_id_valid then
                local instance = allegro5.al_lock_sample_id(sample_id)
                if instance then
                    allegro5.al_set_sample_instance_pan(instance, sin(allegro5.al_get_time()))
                end
                allegro5.al_unlock_sample_id(sample_id)
            end
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0., 0., 0.))
            allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1., 0.5, 0.5), 12, y,
                allegro5.ALLEGRO_ALIGN_LEFT, "CONTROLS")
            y = y + dy
            allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1., 0.5, 0.5), 12, y,
                allegro5.ALLEGRO_ALIGN_LEFT, "1-9 - play the sounds")
            y = y + dy
            allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1., 0.5, 0.5), 12, y,
                allegro5.ALLEGRO_ALIGN_LEFT, "SPACE - stop all sounds")
            y = y + dy
            allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1., 0.5, 0.5), 12, y,
                allegro5.ALLEGRO_ALIGN_LEFT, "Ctrl 1-9 - play sounds with bidirectional looping")
            y = y + dy
            allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1., 0.5, 0.5), 12, y,
                allegro5.ALLEGRO_ALIGN_LEFT, "Alt 1-9 - play sounds with regular looping")
            y = y + dy
            allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1., 0.5, 0.5), 12, y,
                allegro5.ALLEGRO_ALIGN_LEFT, "Shift 1-9 - play sounds reversed")
            y = y + dy
            allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1., 0.5, 0.5), 12, y,
                allegro5.ALLEGRO_ALIGN_LEFT, "p - pan the last played sound")
            y = y + dy
            allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1., 0.5, 0.5), 12, y,
                allegro5.ALLEGRO_ALIGN_LEFT, "m - play music")
            y = y + 2 * dy
            allegro5.al_draw_text(font, allegro5.al_map_rgb_f(0.5, 1., 0.5), 12, y,
                allegro5.ALLEGRO_ALIGN_LEFT, "SOUNDS")
            y = y + dy
            for i = 1, math.min(argc, MAX_SAMPLE_DATA) do
                local filename = argv[i]
                if startswith(filename, env.ALLEGRO_EXAMPLES_DATA_PATH .. "/") then
                    filename = "data/" .. filename:sub(string.len(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/") + 1)
                end

                allegro5.al_draw_text(font, allegro5.al_map_rgb_f(0.5, 1., 0.5), 12, y,
                    allegro5.ALLEGRO_ALIGN_LEFT, string.format("%d - %s", i, filename))
                y = y + dy
            end
            allegro5.al_flip_display()
        end
    end

    for i = 1, math.min(argc, MAX_SAMPLE_DATA) do
        if sample_data[i] then
            allegro5.al_destroy_sample(sample_data[i])
        end
    end

    --[[ Sample data and other objects will be automatically freed. --]]
    allegro5.al_uninstall_audio()

    allegro5.al_destroy_display(display)
    close_log(true)
    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
