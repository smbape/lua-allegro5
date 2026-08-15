#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_record_name.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local pointer_cast = common.pointer_cast

local INDEX_BASE = 1 -- lua is 1-based indexed

local sizeof_int16_t = allegro5_lua.ffi.sizeof("int16_t")
local memcpy = allegro5_lua.C.memcpy

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")

    sizeof_int16_t = ffi.sizeof("int16_t")
    memcpy = ffi.C.memcpy
end

--[[ ex_record_name
 -
 - This example automatically detects when you say your name and creates a
 - sample (maximum of three seconds). Pressing any key (other than ESC) will
 - play it back.
 --]]

local function main()
    local font_height = 0

    --[[ Frequency is the number of samples per second. --]]
    local frequency = 44100

    local channels = 2

    --[[ The latency is used to determine the size of the fragment buffer.
      More accurately, it represents approximately how many seconds will
      pass between fragment events. (There may be overhead latency from
      the OS or driver the adds a fixed amount of latency on top of
      Allegro's.)

      For this example, the latency should be kept relatively low since
      each fragment is processed in its entirety. Increasing the latency
      would increase the size of the fragment, which would decrease the
      accuracy of the code that processes the fragment.

      But if it's too low, then it will cut out too quickly. (If the
      example were more thoroughly written, the latency setting wouldn't
      actually change how the voice detection worked.)
    --]]
    local latency = 0.10

    local max_seconds = 3 --[[ number of seconds of voice recording --]]

    local name_buffer --[[ stores up to max_seconds of audio --]]
    local name_buffer_pos --[[ points to the current recorded position --]]
    local name_buffer_end --[[ points to the end of the buffer --]]

    local gain = 0.0 --[[ 0.0 (quiet) - 1.0 (loud) --]]
    local begin_gain = 0.3 --[[ when to begin recording --]]

    local is_recording = false

    local spl = nil

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    if not allegro5.al_install_audio() then
        abort_example("Unable to initialize audio addon\n")
    end

    if not allegro5.al_init_acodec_addon() then
        abort_example("Unable to initialize acoded addon\n")
    end

    if not allegro5.al_init_image_addon() then
        abort_example("Unable to initialize image addon\n")
    end

    if not allegro5.al_init_primitives_addon() then
        abort_example("Unable to initialize primitives addon\n")
    end

    allegro5.al_init_font_addon()
    allegro5.al_install_keyboard()

    local font = allegro5.al_load_bitmap_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bmpfont.tga")
    if not font then
        abort_example("Unable to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bmpfont.tga\n")
    end

    font_height = allegro5.al_get_font_line_height(font)

    --[[ WARNING: This demo assumes an audio depth of INT16 and two channels.
      Changing those values will break the demo. Nothing here really needs to be
      changed. If you want to fiddle with things, adjust the constants at the
      beginning of the program.
    --]]

    local recorder = allegro5.al_create_audio_recorder(
        5 / latency, --[[ five seconds of buffer space --]]
        frequency * latency, --[[ configure the fragment size to give us the given
                                        latency in seconds --]]
        frequency, --[[ samples per second (higher => better quality) --]]
        allegro5.ALLEGRO_AUDIO_DEPTH_INT16, --[[ 2-byte sample size --]]
        allegro5.ALLEGRO_CHANNEL_CONF_2 --[[ stereo --]]
    )

    if not recorder then
        abort_example("Unable to create audio recorder\n")
    end

    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Unable to create display\n")
    end

    --[[ Used to play back the voice recording. --]]
    allegro5.al_reserve_samples(1)

    --[[ store up to three seconds --]]
    name_buffer = pointer_cast("int16_t", allegro5.al_calloc(channels * frequency * max_seconds, sizeof_int16_t))
    name_buffer_pos = name_buffer
    name_buffer_end = name_buffer + channels * frequency * max_seconds

    local queue = allegro5.al_create_event_queue()
    local timer = allegro5.al_create_timer(1 / 60.0)

    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_audio_recorder_event_source(recorder))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())

    allegro5.al_start_timer(timer)
    allegro5.al_start_audio_recorder(recorder)

    while true do
        local event = allegro5.ALLEGRO_EVENT()
        local do_draw = false

        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE or
            (event.type == allegro5.ALLEGRO_EVENT_KEY_UP and event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE) then
            break
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if spl and event.keyboard.unichar ~= 27 then
                allegro5.al_play_sample(spl, 1.0, 0.0, 1.0, allegro5.ALLEGRO_PLAYMODE_ONCE, nil)
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            do_draw = true
        elseif event.type == allegro5.ALLEGRO_EVENT_AUDIO_RECORDER_FRAGMENT and recorder ~= nil then
            --[[ Because the recording happens in a different thread (and simply because we are
            queuing up events), it's quite possible to receive (process) a fragment event
            after the recorder has been stopped or destroyed. Thus, it is important to
            somehow check that the recorder is still valid, as we are doing above.
          --]]
            local re = allegro5.al_get_audio_recorder_event(event)
            local buffer = pointer_cast("int16_t", re.buffer)
            local low, high = 0, 0

            --[[ Calculate the volume by comparing the highest and lowest points. This entire
            section assumes we are using fairly small fragment size (low latency). If a
            large fragment size were used, then we'd have to inspect smaller portions
            of it at a time to more accurately deterine when recording started and
            stopped. --]]
            for i = 0, channels * re.samples - INDEX_BASE do
                if buffer[i] < low then
                    low = buffer[i]
                elseif buffer[i] > high then
                    high = buffer[i]
                end
            end

            gain = gain * 0.25 + ((high - low) / 0xffff) * 0.75

            --[[ Set arbitrary thresholds for beginning and stopping recording. This probably
            should be calibrated by determining how loud the ambient noise is.
          --]]
            if not is_recording and gain >= begin_gain and name_buffer_pos == name_buffer then
                is_recording = true
            elseif is_recording and gain <= 0.10 then
                is_recording = false
            end

            if is_recording then
                --[[ Copy out of the fragment buffer into our own buffer that holds the
               name. --]]
                local samples_to_copy = channels * re.samples

                --[[ Don't overfill up our name buffer... --]]
                if samples_to_copy > name_buffer_end - name_buffer_pos then
                    samples_to_copy = name_buffer_end - name_buffer_pos
                end

                if samples_to_copy then
                    --[[ must multiply by two, since we are using 16-bit samples --]]
                    memcpy(name_buffer_pos, re.buffer, samples_to_copy * 2)
                end

                name_buffer_pos = name_buffer_pos + (samples_to_copy)
                if name_buffer_pos >= name_buffer_end then
                    is_recording = false
                end
            end

            if not is_recording and name_buffer_pos ~= name_buffer and not spl then
                --[[ finished recording, but haven't created the sample yet --]]
                spl = allegro5.al_create_sample(name_buffer, name_buffer_pos - name_buffer, frequency,
                    allegro5.ALLEGRO_AUDIO_DEPTH_INT16, allegro5.ALLEGRO_CHANNEL_CONF_2, false)

                --[[ We no longer need the recorder. Destroying it is the only way to unlock the device. --]]
                allegro5.al_destroy_audio_recorder(recorder)
                recorder = nil
            end
        end

        if do_draw then
            allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))
            if not spl then
                local msg = "Say Your Name"
                local width = allegro5.al_get_text_width(font, msg)

                allegro5.al_draw_text(font, allegro5.al_map_rgb(255, 255, 255),
                    320, 240 - font_height / 2, allegro5.ALLEGRO_ALIGN_CENTRE, msg
                )

                --[[ draw volume meter --]]
                allegro5.al_draw_filled_rectangle(320 - width / 2, 242 + font_height / 2,
                    (320 - width / 2) + (gain * width), 242 + font_height,
                    allegro5.al_map_rgb(0, 255, 0)
                )

                --[[ draw target line that triggers recording --]]
                allegro5.al_draw_line((320 - width / 2) + (begin_gain * width), 242 + font_height / 2,
                    (320 - width / 2) + (begin_gain * width), 242 + font_height,
                    allegro5.al_map_rgb(255, 255, 0), 1.0
                )
            else
                allegro5.al_draw_text(font, allegro5.al_map_rgb(255, 255, 255), 320, 240 - font_height / 2,
                    allegro5.ALLEGRO_ALIGN_CENTRE, "Press Any Key")
            end
            allegro5.al_flip_display()
        end
    end

    if recorder then
        allegro5.al_destroy_audio_recorder(recorder)
    end

    allegro5.al_free(name_buffer)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
