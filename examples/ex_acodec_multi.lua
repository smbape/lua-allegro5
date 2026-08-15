#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_acodec_multi.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 - Milan Mimica
 - Audio example that plays multiple files at the same time
 - Originlly derived from the ex_acodec example.
 --]]

local default_files = { env.ALLEGRO_EXAMPLES_DATA_PATH .. "/welcome.voc",
    env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/earth_0.ogg", env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/water_0.ogg",
    env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/fire_0.ogg", env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/air_0.ogg" }

local function main(argv)
    local argc = #argv

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    if argc < 1 then
        log_printf("This example can be run from the command line.\nUsage: %s {audio_files}\n", argv[0])
        argv = default_files
        argc = #argv
    end

    allegro5.al_init_acodec_addon()

    if not allegro5.al_install_audio() then
        abort_example("Could not init sound!\n")
    end

    local sample = {}

    local sample_data = {}

    --[[ a voice is used for playback --]]
    local voice = allegro5.al_create_voice(44100, allegro5.ALLEGRO_AUDIO_DEPTH_INT16,
        allegro5.ALLEGRO_CHANNEL_CONF_2)
    if not voice then
        abort_example("Could not create ALLEGRO_VOICE from sample\n")
    end

    local mixer = allegro5.al_create_mixer(44100, allegro5.ALLEGRO_AUDIO_DEPTH_FLOAT32,
        allegro5.ALLEGRO_CHANNEL_CONF_2)
    if not mixer then
        abort_example("al_create_mixer failed.\n")
    end

    if not allegro5.al_attach_mixer_to_voice(mixer, voice) then
        abort_example("al_attach_mixer_to_voice failed.\n")
    end

    for i = 1, argc - INDEX_BASE do
        local filename = argv[i]

        --[[ loads the entire sound file from disk into sample data --]]
        sample_data[i] = allegro5.al_load_sample(filename)
        if not sample_data[i] then
            abort_example("Could not load sample from '%s'!\n", filename)
        end

        sample[i] = allegro5.al_create_sample_instance(sample_data[i])
        if not sample[i] then
            log_printf("Could not create sample from '%s'!\n", filename)
            allegro5.al_destroy_sample(sample_data[i])
            sample_data[i] = nil
        elseif not allegro5.al_attach_sample_instance_to_mixer(sample[i], mixer) then
            log_printf("al_attach_sample_instance_to_mixer from '%s' failed.\n", filename)
        end
    end

    local longest_sample = 0

    for i = 1, argc do
        local filename = argv[i]
        local sample_time = 0

        if sample[i] then
            --[[ play each sample once --]]
            allegro5.al_play_sample_instance(sample[i])

            sample_time = allegro5.al_get_sample_instance_time(sample[i])
            log_printf("Playing '%s' (%.3f seconds)\n", filename, sample_time)

            if sample_time > longest_sample then
                longest_sample = sample_time
            end
        end
    end

    allegro5.al_rest(longest_sample)

    log_printf("Done\n")

    for i = 1, argc - INDEX_BASE do
        --[[ free the memory allocated when creating the sample + voice --]]
        if sample[i] then
            allegro5.al_stop_sample_instance(sample[i])
            allegro5.al_destroy_sample_instance(sample[i])
            allegro5.al_destroy_sample(sample_data[i])
        end
    end
    allegro5.al_destroy_mixer(mixer)
    allegro5.al_destroy_voice(voice)

    allegro5.al_uninstall_audio()

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
