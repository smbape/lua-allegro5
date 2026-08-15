#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_saw.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf
local pointer_cast = common.pointer_cast
local int8_t_cast = common.int8_t_cast

local env = common.env

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ Recreate exstream.c from A4. --]]

local SAMPLES_PER_BUFFER = 1024

local function saw(stream)
    local pitch = 0x10000
    local val = 0
    local n = 200

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_audio_stream_event_source(stream))
    if env.ALLEGRO_POPUP_EXAMPLES then
        if common.textlog then
            allegro5.al_register_event_source(queue, allegro5.al_get_native_text_log_event_source(common.textlog))
        end
    end

    log_printf("Generating saw wave...\n")

    while n > 0 do
        local event = allegro5.ALLEGRO_EVENT()

        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_AUDIO_STREAM_FRAGMENT then
            local buf = pointer_cast("int8_t", allegro5.al_get_audio_stream_fragment(stream))
            --[[ This is a normal condition you must deal with. --]]
            if buf then
                for i = 0, SAMPLES_PER_BUFFER - INDEX_BASE do
                    --[[ Crude saw wave at maximum amplitude. Please keep this compatible
                 - to the A4 example so we know when something has broken for now.
                 -
                 - It would be nice to have a better example with user interface
                 - and some simple synth effects.
                 --]]
                    buf[i] = int8_t_cast(bit.rshift(val, 16))
                    val = val + pitch
                    pitch = pitch + 1
                end

                if not allegro5.al_set_audio_stream_fragment(stream, buf) then
                    log_printf("Error setting stream fragment.\n")
                end

                n = n - 1
                if (n % 10) == 0 then
                    log_printf(".")
                end
            end
        end

        if env.ALLEGRO_POPUP_EXAMPLES then
            if event.type == allegro5.ALLEGRO_EVENT_NATIVE_DIALOG_CLOSE then
                break
            end
        end
    end

    allegro5.al_drain_audio_stream(stream)

    log_printf("\n")

    allegro5.al_destroy_event_queue(queue)
end


local function main()
    local buf

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    if not allegro5.al_install_audio() then
        abort_example("Could not init sound.\n")
    end
    allegro5.al_reserve_samples(0)

    local stream = allegro5.al_create_audio_stream(8, SAMPLES_PER_BUFFER, 22050,
        allegro5.ALLEGRO_AUDIO_DEPTH_UINT8, allegro5.ALLEGRO_CHANNEL_CONF_1)
    while ((function()
            buf = allegro5.al_get_audio_stream_fragment(stream); return buf
        end)()) do
        allegro5.al_fill_silence(buf, SAMPLES_PER_BUFFER, allegro5.ALLEGRO_AUDIO_DEPTH_UINT8,
            allegro5.ALLEGRO_CHANNEL_CONF_1)
        allegro5.al_set_audio_stream_fragment(stream, buf)
    end

    if not stream then
        abort_example("Could not create stream.\n")
    end

    if not allegro5.al_attach_audio_stream_to_mixer(stream, allegro5.al_get_default_mixer()) then
        abort_example("Could not attach stream to mixer.\n")
    end

    open_log()

    saw(stream)

    close_log(false)

    allegro5.al_destroy_audio_stream(stream)
    allegro5.al_uninstall_audio()

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
