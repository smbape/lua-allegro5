#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_acodec.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf
local new_array = common.new_array

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 - Ryan Dickie
 - Audio example that loads a series of files and puts them through the mixer.
 - Originlly derived from the audio example on the wiki.
 --]]

local function main(argv)
    local argc = #argv

    local filenames = {}
    local n = 0

    if argc < 1 then
        n = 1
        filenames[#filenames + 1] = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/welcome.wav"
    else
        n = argc
        for i = 1, argc do
            filenames[#filenames + 1] = argv[i]
        end
    end

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    allegro5.al_init_acodec_addon()

    if not allegro5.al_install_audio() then
        abort_example("Could not init sound!\n")
    end

    local voice = allegro5.al_create_voice(44100, allegro5.ALLEGRO_AUDIO_DEPTH_INT16,
        allegro5.ALLEGRO_CHANNEL_CONF_2)
    if not voice then
        abort_example("Could not create ALLEGRO_VOICE.\n")
    end

    local mixer = allegro5.al_create_mixer(44100, allegro5.ALLEGRO_AUDIO_DEPTH_FLOAT32,
        allegro5.ALLEGRO_CHANNEL_CONF_2)
    if not mixer then
        abort_example("al_create_mixer failed.\n")
    end

    if not allegro5.al_attach_mixer_to_voice(mixer, voice) then
        abort_example("al_attach_mixer_to_voice failed.\n")
    end

    local sample = allegro5.al_create_sample_instance(nil)
    if not sample then
        abort_example("al_create_sample failed.\n")
    end

    for i = 1, n do
        local filename = filenames[i]
        local sample_time = 0
        --[[ A matrix that puts everything in the left channel. --]]
        local mono_to_stereo = new_array("float", { 1.0, 0.0 })

        --[[ Load the entire sound file from disk. --]]
        local sample_data = allegro5.al_load_sample(filename)
        if not sample_data then
            abort_example("Could not load sample from '%s'!\n", filename)
        end

        if not allegro5.al_set_sample(sample, sample_data) then
            abort_example("al_set_sample_instance_ptr failed.\n")
        end

        if not allegro5.al_attach_sample_instance_to_mixer(sample, mixer) then
            abort_example("al_attach_sample_instance_to_mixer failed.\n")
        end

        --[[ Play sample in looping mode. --]]
        allegro5.al_set_sample_instance_playmode(sample, allegro5.ALLEGRO_PLAYMODE_LOOP)
        allegro5.al_play_sample_instance(sample)

        sample_time = allegro5.al_get_sample_instance_time(sample)
        log_printf("Playing '%s' (%.3f seconds) normally.\n", filename,
            sample_time)

        allegro5.al_rest(sample_time)

        if allegro5.al_get_channel_count(allegro5.al_get_sample_instance_channels(sample)) == 1 then
            if not allegro5.al_set_sample_instance_channel_matrix(sample, mono_to_stereo) then
                abort_example("Failed to set channel matrix.\n")
            end
            log_printf("Playing left channel only.\n")
            allegro5.al_rest(sample_time)
        end

        if not allegro5.al_set_sample_instance_gain(sample, 0.5) then
            abort_example("Failed to set gain.\n")
        end
        log_printf("Playing with gain 0.5.\n")
        allegro5.al_rest(sample_time)

        if not allegro5.al_set_sample_instance_gain(sample, 0.25) then
            abort_example("Failed to set gain.\n")
        end
        log_printf("Playing with gain 0.25.\n")
        allegro5.al_rest(sample_time)

        allegro5.al_stop_sample_instance(sample)
        log_printf("Done playing '%s'\n", filename)

        --[[ Free the memory allocated. --]]
        allegro5.al_set_sample(sample, nil)
        allegro5.al_destroy_sample(sample_data)
    end

    allegro5.al_destroy_sample_instance(sample)
    allegro5.al_destroy_mixer(mixer)
    allegro5.al_destroy_voice(voice)

    allegro5.al_uninstall_audio()

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
