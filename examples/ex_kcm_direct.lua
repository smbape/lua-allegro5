#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_kcm_direct.c
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

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ Shows the ability to play a sample without a mixer. --]]

local default_files = { env.ALLEGRO_EXAMPLES_DATA_PATH .. "/welcome.wav" }

local function main(argv)
    local argc = #argv

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    if argc < 1 then
        log_printf("This example can be run from the command line.\nUsage: %s {audio_files}\n", argv[0])
        argv = default_files
        argc = #default_files
    end

    allegro5.al_init_acodec_addon()

    if not allegro5.al_install_audio() then
        abort_example("Could not init sound!\n")
    end

    for i = 1, argc do
        local filename = argv[i]

        --[[ Load the entire sound file from disk. --]]
        local sample_data = allegro5.al_load_sample(filename)
        if not sample_data then
            abort_example("Could not load sample from '%s'!\n",
                filename)
        end

        local sample = allegro5.al_create_sample_instance(nil)
        if not sample then
            abort_example("al_create_sample failed.\n")
        end

        if not allegro5.al_set_sample(sample, sample_data) then
            abort_example("al_set_sample failed.\n")
        end

        local depth = allegro5.al_get_sample_instance_depth(sample)
        local chan = allegro5.al_get_sample_instance_channels(sample)
        local freq = allegro5.al_get_sample_instance_frequency(sample)
        log_printf("Loaded sample: %i-bit depth, %i channels, %i Hz\n",
            (function() if (depth < 8) then return (8 + depth * 8) else return 0 end end)(),
            (bit.rshift(chan, 4)) + (chan % 0xF), freq)
        log_printf("Trying to create a voice with the same specs... ")
        local voice = allegro5.al_create_voice(freq, depth, chan)
        if not voice then
            abort_example("Could not create ALLEGRO_VOICE.\n")
        end
        log_printf("done.\n")

        if not allegro5.al_attach_sample_instance_to_voice(sample, voice) then
            abort_example("al_attach_sample_instance_to_voice failed.\n")
        end

        --[[ Play sample in looping mode. --]]
        allegro5.al_set_sample_instance_playmode(sample, allegro5.ALLEGRO_PLAYMODE_LOOP)
        allegro5.al_play_sample_instance(sample)

        local sample_time = allegro5.al_get_sample_instance_time(sample)
        log_printf("Playing '%s' (%.3f seconds) 3 times", filename,
            sample_time)

        allegro5.al_rest(sample_time * 3)

        allegro5.al_stop_sample_instance(sample)
        log_printf("\n")

        --[[ Free the memory allocated. --]]
        allegro5.al_set_sample(sample, nil)
        allegro5.al_destroy_sample(sample_data)
        allegro5.al_destroy_sample_instance(sample)
        allegro5.al_destroy_voice(voice)
    end

    allegro5.al_uninstall_audio()
    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})

--[[ vim: set sts=3 sw=3 et: --]]
