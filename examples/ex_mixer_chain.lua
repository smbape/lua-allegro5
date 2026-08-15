#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_mixer_chain.c
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
 -    Example program for the Allegro library.
 -
 -    Test chaining mixers to mixers.
 --]]

local default_files = { env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/water_0.ogg",
    env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/water_7.ogg" }

local function main(argv)
    local argc = #argv

    local submixer = {}
    local sample = {}
    local sample_data = {}

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    if argc < 2 then
        log_printf("This example can be run from the command line.\nUsage: %s file1 file2\n", argv[0])
        argv = default_files
        argc = 3
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

    local mixer = allegro5.al_create_mixer(44100, allegro5.ALLEGRO_AUDIO_DEPTH_FLOAT32,
        allegro5.ALLEGRO_CHANNEL_CONF_2)
    submixer[0 + INDEX_BASE] = allegro5.al_create_mixer(44100, allegro5.ALLEGRO_AUDIO_DEPTH_FLOAT32,
        allegro5.ALLEGRO_CHANNEL_CONF_2)
    submixer[1 + INDEX_BASE] = allegro5.al_create_mixer(44100, allegro5.ALLEGRO_AUDIO_DEPTH_FLOAT32,
        allegro5.ALLEGRO_CHANNEL_CONF_2)
    if not mixer or not submixer[0 + INDEX_BASE] or not submixer[1 + INDEX_BASE] then
        abort_example("al_create_mixer failed.\n")
    end

    if not allegro5.al_attach_mixer_to_voice(mixer, voice) then
        abort_example("al_attach_mixer_to_voice failed.\n")
    end

    for i = 1, 2 do
        local filename = argv[i]
        sample_data[i] = allegro5.al_load_sample(filename)
        if not sample_data[i] then
            abort_example("Could not load sample from '%s'!\n", filename)
        end
        sample[i] = allegro5.al_create_sample_instance(nil)
        if not sample[i] then
            abort_example("al_create_sample failed.\n")
        end
        if not allegro5.al_set_sample(sample[i], sample_data[i]) then
            abort_example("al_set_sample_ptr failed.\n")
        end
        if not allegro5.al_attach_sample_instance_to_mixer(sample[i], submixer[i]) then
            abort_example("al_attach_sample_instance_to_mixer failed.\n")
        end
        if not allegro5.al_attach_mixer_to_mixer(submixer[i], mixer) then
            abort_example("al_attach_mixer_to_mixer failed.\n")
        end
    end

    --[[ Play sample in looping mode. --]]
    for i = 1, 2 do
        allegro5.al_set_sample_instance_playmode(sample[i], allegro5.ALLEGRO_PLAYMODE_LOOP)
        allegro5.al_play_sample_instance(sample[i])
    end

    local max_sample_time = allegro5.al_get_sample_instance_time(sample[0 + INDEX_BASE])
    local sample_time = allegro5.al_get_sample_instance_time(sample[1 + INDEX_BASE])
    if sample_time > max_sample_time then
        max_sample_time = sample_time
    end

    log_printf("Playing...")

    allegro5.al_rest(max_sample_time)

    allegro5.al_set_sample_instance_gain(sample[0 + INDEX_BASE], 0.5)
    allegro5.al_rest(max_sample_time)

    allegro5.al_set_sample_instance_gain(sample[1 + INDEX_BASE], 0.25)
    allegro5.al_rest(max_sample_time)

    allegro5.al_stop_sample_instance(sample[0 + INDEX_BASE])
    allegro5.al_stop_sample_instance(sample[1 + INDEX_BASE])
    log_printf("Done\n")

    --[[ Free the memory allocated. --]]
    for i = 1, 2 do
        allegro5.al_set_sample(sample[i], nil)
        allegro5.al_destroy_sample(sample_data[i])
        allegro5.al_destroy_sample_instance(sample[i])
        allegro5.al_destroy_mixer(submixer[i])
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
