#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_record.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local pointer_cast = common.pointer_cast

local INDEX_BASE = 1 -- lua is 1-based indexed

local abs = math.abs

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ ex_record
 -
 - Press spacebar to begin and stop recording. Press 'p' to play back the
 - previous recording. Up to five minutes of audio will be recorded.
 -
 - The raw sample data is saved to a temporary file and played back via
 - an audio stream. Thus, minimal memory is used regardless of the length of
 - recording.
 -
 - When recording, it's important to keep the distinction between bytes and
 - samples. A sample is only exactly one byte long if it is 8-bit and mono.
 - Otherwise it is multiple bytes. The recording functions always work with
 - sample counts. However, when using things like memcpy() or fwrite(), you
 - will be working with bytes.
 --]]

--[[ The following constants are needed so that the rest of the code can
 - work independent from the audio depth. Both 8-bit and 16-bit should be
 - supported by all devices, so in your own programs you probably can get by
 - with just supporting one or the other.
 --]]

local audio_depth
local audio_buffer_t
local sample_center
local min_sample_val
local max_sample_val
local sample_range
local sample_size

if os.getenv("WANT_8_BIT_DEPTH") == nil or os.getenv("WANT_8_BIT_DEPTH") ~= "0" then
    audio_depth = allegro5.ALLEGRO_AUDIO_DEPTH_UINT8
    audio_buffer_t = "uint8_t"
    sample_center = 128
    min_sample_val = -0x80
    max_sample_val = 0x7f
    sample_range = 0xff
    sample_size = 1
else
    audio_depth = allegro5.ALLEGRO_AUDIO_DEPTH_INT16
    audio_buffer_t = "int16_t"
    sample_center = 0
    min_sample_val = -0x8000
    max_sample_val = 0x7fff
    sample_range = 0xffff
    sample_size = 2
end

--[[ How many samples do we want to process at one time?
   Let's pick a multiple of the width of the screen so that the
   visualization graph is easy to draw. --]]
local samples_per_fragment = 320 * 4

--[[ Frequency is the quality of audio. (Samples per second.) Higher
   quality consumes more memory. For speech, numbers as low as 8000
   can be good enough. 44100 is often used for high quality recording. --]]
local frequency = 22050
local max_seconds_to_record = 60 * 5


--[[ The playback buffer specs don't need to match the recording sizes.
 - The values here are slightly large to help make playback more smooth.
 --]]
local playback_fragment_count = 4
local playback_samples_per_fragment = 4096

local function main()
    local fp = nil
    local tmp_path = nil

    local prev = 0
    local is_recording = false

    local n = 0 --[[ number of samples written to disk --]]

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    if not allegro5.al_init_primitives_addon() then
        abort_example("Unable to initialize primitives addon")
    end

    if not allegro5.al_install_keyboard() then
        abort_example("Unable to install keyboard")
    end

    if not allegro5.al_install_audio() then
        abort_example("Unable to initialize audio addon")
    end

    if not allegro5.al_init_acodec_addon() then
        abort_example("Unable to initialize acodec addon")
    end

    --[[ Note: increasing the number of channels will break this demo. Other
    - settings can be changed by modifying the constants at the top of the
    - file.
    --]]
    local r = allegro5.al_create_audio_recorder(1000, samples_per_fragment, frequency,
        audio_depth, allegro5.ALLEGRO_CHANNEL_CONF_1)
    if not r then
        abort_example("Unable to create audio recorder")
    end

    local s = allegro5.al_create_audio_stream(playback_fragment_count,
        playback_samples_per_fragment, frequency, audio_depth,
        allegro5.ALLEGRO_CHANNEL_CONF_1)
    if not s then
        abort_example("Unable to create audio stream")
    end

    allegro5.al_reserve_samples(0)
    allegro5.al_set_audio_stream_playing(s, false)
    allegro5.al_attach_audio_stream_to_mixer(s, allegro5.al_get_default_mixer())

    local q = allegro5.al_create_event_queue()

    --[[ Note: the following two options are referring to pixel samples, and have
    - nothing to do with audio samples. --]]
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLE_BUFFERS, 1, allegro5.ALLEGRO_SUGGEST)
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLES, 8, allegro5.ALLEGRO_SUGGEST)

    local d = allegro5.al_create_display(320, 256)
    if not d then
        abort_example("Error creating display\n")
    end

    allegro5.al_set_window_title(d, "SPACE to record. P to playback.")

    allegro5.al_register_event_source(q, allegro5.al_get_audio_recorder_event_source(r))
    allegro5.al_register_event_source(q, allegro5.al_get_audio_stream_event_source(s))
    allegro5.al_register_event_source(q, allegro5.al_get_display_event_source(d))
    allegro5.al_register_event_source(q, allegro5.al_get_keyboard_event_source())

    allegro5.al_start_audio_recorder(r)

    while true do
        local e = allegro5.ALLEGRO_EVENT()

        allegro5.al_wait_for_event(q, e)

        if e.type == allegro5.ALLEGRO_EVENT_AUDIO_RECORDER_FRAGMENT then
            --[[ We received an incoming fragment from the microphone. In this
          - example, the recorder is constantly recording even when we aren't
          - saving to disk. The display is updated every time a new fragment
          - comes in, because it makes things more simple. If the fragments
          - are coming in faster than we can update the screen, then it will be
          - a problem.
          --]]
            local re = allegro5.al_get_audio_recorder_event(e)
            local input = pointer_cast(audio_buffer_t, re.buffer)
            local sample_count = re.samples
            local R = math.floor(sample_count / 320)
            local gain = 0

            --[[ Calculate the volume, and display it regardless if we are actively
          - recording to disk. --]]
            for i = 0, sample_count - INDEX_BASE do
                if gain < abs(input[i] - sample_center) then
                    gain = abs(input[i] - sample_center)
                end
            end

            allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))

            if is_recording then
                --[[ Save raw bytes to disk. Assumes everything is written
             - succesfully. --]]
                if fp and n < frequency / samples_per_fragment *
                    max_seconds_to_record then
                    allegro5.al_fwrite(fp, input, sample_count * sample_size)
                    n = n + 1
                end

                --[[ Draw a pathetic visualization. It draws exactly one fragment
             - per frame. This means the visualization is dependent on the
             - various parameters. A more thorough implementation would use this
             - event to copy the new data into a circular buffer that holds a
             - few seconds of audio. The graphics routine could then always
             - draw that last second of audio, which would cause the
             - visualization to appear constant across all different settings.
             --]]
                for i = 0, 320 - INDEX_BASE do
                    local j, c = 0, 0

                    --[[ Take the average of R samples so it fits on the screen --]]
                    j = i * R
                    while j < i * R + R and j < sample_count do
                        c = c + (input[j] - sample_center)
                        j = j + 1
                    end
                    c = math.floor(c / R)

                    --[[ Draws a line from the previous sample point to the next --]]
                    allegro5.al_draw_line(i - 1, 128 + ((prev - min_sample_val) /
                            sample_range) * 256 - 128, i, 128 +
                        ((c - min_sample_val) / sample_range) * 256 - 128,
                        allegro5.al_map_rgb(255, 255, 255), 1.2)

                    prev = c
                end
            end

            --[[ draw volume bar --]]
            allegro5.al_draw_filled_rectangle((gain / max_sample_val) * 320, 251,
                0, 256, allegro5.al_map_rgba(0, 255, 0, 128))

            allegro5.al_flip_display()
        elseif e.type == allegro5.ALLEGRO_EVENT_AUDIO_STREAM_FRAGMENT then
            --[[ This event is received when we are playing back the audio clip.
          - See ex_saw.c for an example dedicated to playing streams.
          --]]
            if fp then
                local output = pointer_cast(audio_buffer_t, allegro5.al_get_audio_stream_fragment(s))
                if output then
                    --[[ Fill the buffer from the data we have recorded into the file.
                - If an error occurs (or end of file) then silence out the
                - remainder of the buffer and stop the playback.
                --]]
                    local bytes_to_read = playback_samples_per_fragment * sample_size
                    local bytes_read = 0

                    repeat
                        bytes_read = bytes_read + (allegro5.al_fread(fp, pointer_cast("uint8_t", output) + bytes_read,
                            bytes_to_read - bytes_read))
                    until not (bytes_read < bytes_to_read and not allegro5.al_feof(fp) and
                            allegro5.al_ferror(fp) ~= 0)

                    --[[ silence out unused part of buffer (end of file) --]]
                    for i = tonumber(bytes_read / sample_size),
                    bytes_to_read / sample_size - INDEX_BASE do
                        output[i] = sample_center
                    end

                    allegro5.al_set_audio_stream_fragment(s, output)

                    if allegro5.al_ferror(fp) ~= 0 or allegro5.al_feof(fp) then
                        allegro5.al_drain_audio_stream(s)
                        allegro5.al_fclose(fp)
                        fp = nil
                    end
                end
            end
        elseif e.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        elseif e.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if e.keyboard.unichar == 27 then
                --[[ pressed ESC --]]
                break
            elseif e.keyboard.unichar == string.byte(' ') then
                if not is_recording then
                    --[[ Start the recording --]]
                    is_recording = true

                    if allegro5.al_get_audio_stream_playing(s) then
                        allegro5.al_drain_audio_stream(s)
                    end

                    --[[ Reuse the same temp file for all recordings --]]
                    if not tmp_path then
                        fp, tmp_path = allegro5.al_make_temp_file("alrecXXX.raw")
                    else
                        if fp then
                            allegro5.al_fclose(fp)
                        end
                        fp = allegro5.al_fopen(allegro5.al_path_cstr(tmp_path, '/'), "w")
                    end

                    n = 0
                else
                    is_recording = false
                    if fp then
                        allegro5.al_fclose(fp)
                        fp = nil
                    end
                end
            elseif e.keyboard.unichar == string.byte('p') then
                --[[ Play the previously recorded wav file --]]
                if not is_recording then
                    if tmp_path then
                        fp = allegro5.al_fopen(allegro5.al_path_cstr(tmp_path, '/'), "r")
                        if fp then
                            allegro5.al_set_audio_stream_playing(s, true)
                        end
                    end
                end
            end
        end
    end

    --[[ clean up --]]
    allegro5.al_destroy_audio_recorder(r)
    allegro5.al_destroy_audio_stream(s)

    if fp then
        allegro5.al_fclose(fp)
    end

    if tmp_path then
        allegro5.al_remove_filename(allegro5.al_path_cstr(tmp_path, '/'))
        allegro5.al_destroy_path(tmp_path)
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
