#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_stream_file.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf
local startswith = common.startswith

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 - An example program that plays a file from the disk using Allegro5
 - streaming API. The file is being read in small chunks and played on the
 - sound device instead of being loaded at once.
 -
 - usage: ./ex_stream_file file.[wav,ogg...] ...
 -
 - by Milan Mimica
 --]]

--[[ Attaches the stream directly to a voice. Streamed file's and voice's sample
 - rate, channels and depth must match.
 --]]
local BYPASS_MIXER = os.getenv("BYPASS_MIXER") == "1"

local default_files = { env.ALLEGRO_EXAMPLES_DATA_PATH .. "/../../demos/skater/data/menu/skate2.ogg" }

local function main(argv)
    local argc = #argv

    local mixer
    local loop = false
    local arg_start = 1

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    if argc > 0 and argv[1] == "--loop" then
        loop = true
        arg_start = 2
    end

    if (argc - arg_start + 1) < 1 then
        log_printf("This example can be run from the command line.\n")
        log_printf("Usage: %s [--loop] {audio_files}\n", argv[0])
        argv = default_files
        argc = #argv
    end

    allegro5.al_init_acodec_addon()

    if not allegro5.al_install_audio() then
        abort_example("Could not init sound!\n")
    end

    local voice = allegro5.al_create_voice(44100, allegro5.ALLEGRO_AUDIO_DEPTH_INT16,
        allegro5.ALLEGRO_CHANNEL_CONF_2)
    if not voice then
        abort_example("Could not create ALLEGRO_VOICE.\n")
    end
    log_printf("Voice created.\n")

    if not BYPASS_MIXER then
        mixer = allegro5.al_create_mixer(44100, allegro5.ALLEGRO_AUDIO_DEPTH_FLOAT32,
            allegro5.ALLEGRO_CHANNEL_CONF_2)
        if not mixer then
            abort_example("Could not create ALLEGRO_MIXER.\n")
        end
        log_printf("Mixer created.\n")

        if not allegro5.al_attach_mixer_to_voice(mixer, voice) then
            abort_example("al_attach_mixer_to_voice failed.\n")
        end
    end

    for i = arg_start, argc do
        local stream
        local filename = argv[i]
        local playing = true
        local event = allegro5.ALLEGRO_EVENT()
        local queue = allegro5.al_create_event_queue()

        if startswith(filename, "data/") then
            filename = env.ALLEGRO_EXAMPLES_DATA_PATH .. filename:sub(string.len("data") + 1)
        end

        stream = allegro5.al_load_audio_stream(filename, 4, 2048)
        if not stream then
            --[[ If it is not packed, e.g. on Android or iOS. --]]
            if filename == default_files[1] then
                stream = allegro5.al_load_audio_stream(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/welcome.wav", 4, 2048)
            end
        end
        if not stream then
            log_printf("Could not create an ALLEGRO_AUDIO_STREAM from '%s'!\n",
                filename)
        else
            log_printf("Stream created from '%s'.\n", filename)
            if loop then
                allegro5.al_set_audio_stream_playmode(stream,
                    (function()
                        if loop then
                            return allegro5.ALLEGRO_PLAYMODE_LOOP
                        else
                            return allegro5
                                .ALLEGRO_PLAYMODE_ONCE
                        end
                    end)())
            end

            allegro5.al_register_event_source(queue, allegro5.al_get_audio_stream_event_source(stream))

            local continue = false
            if not BYPASS_MIXER then
                if not allegro5.al_attach_audio_stream_to_mixer(stream, mixer) then
                    log_printf("al_attach_audio_stream_to_mixer failed.\n")
                    continue = true
                end
            else
                if not allegro5.al_attach_audio_stream_to_voice(stream, voice) then
                    abort_example("al_attach_audio_stream_to_voice failed.\n")
                end
            end

            if not continue then
                log_printf("Playing %s ... Waiting for stream to finish ", filename)
                repeat
                    allegro5.al_wait_for_event(queue, event)
                    if event.type == allegro5.ALLEGRO_EVENT_AUDIO_STREAM_FINISHED then
                        playing = false
                    end
                until not playing
                log_printf("\n")

                allegro5.al_destroy_event_queue(queue)
                allegro5.al_destroy_audio_stream(stream)
            end
        end
    end
    log_printf("Done\n")

    if not BYPASS_MIXER then
        allegro5.al_destroy_mixer(mixer)
    end
    allegro5.al_destroy_voice(voice)

    allegro5.al_uninstall_audio()
    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
