#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_resample_test.c
--]]

local cdef = [[
typedef struct ThreadInfo {
    float waveform[640];
    ALLEGRO_MUTEX *mutex;
    ALLEGRO_COND *cond;
    bool stop_requested;
} ThreadInfo;
]]

local cffi_lua_def = [[
    typedef struct ALLEGRO_MUTEX ALLEGRO_MUTEX;
    typedef struct ALLEGRO_COND ALLEGRO_COND;
    void* memcpy(void* dest, const void* src, size_t count);
]]

local function update_waveform_thread_func(arg)
    local allegro5_lua = require("allegro5_lua")
    local allegro5 = allegro5_lua.allegro5
    local common = require("common")

    local pointer_cast = common.pointer_cast

    local INDEX_BASE = 1 -- lua is 1-based indexed

    local ffi = allegro5_lua.ffi

    if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
        allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
        ffi = require("ffi")
    else
        ffi.cdef(cffi_lua_def)
    end

    local memcpy = ffi.C.memcpy
    ffi.cdef(cdef)

    local info = ffi.cast("ThreadInfo*", arg)
    local waveform = info.waveform
    local waveform_buffer = ffi.new("float [?]", 640)
    local sizeof_float = ffi.sizeof("float")
    local pos = 0

    local function update_waveform(buf, samples, data)
        local fbuf = pointer_cast("float", buf)
        local n = samples

        --[[ Yes, we could do something more advanced, but an oscilloscope of the
        - first 640 samples of each buffer is enough for our purpose here.
        --]]
        if n > 640 then
            n = 640
        end

        for i = 0, n - INDEX_BASE do
            waveform_buffer[pos] = fbuf[i * 2]
            pos = pos + 1
            if pos == 640 then
                memcpy(waveform, waveform_buffer, 640 * sizeof_float)
                pos = 0
                break
            end
        end
    end

    allegro5.al_set_mixer_postprocess_callback(allegro5.al_get_default_mixer(), update_waveform, nil)

    allegro5.al_lock_mutex(info.mutex)
    info.stop_requested = false
    while not info.stop_requested do
        allegro5.al_wait_cond(info.cond, info.mutex)
    end

    allegro5.al_set_mixer_postprocess_callback(allegro5.al_get_default_mixer(), nil, nil)
end

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")
local lanes = require("lanes")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf
local pointer_cast = common.pointer_cast

local env = common.env

local INDEX_BASE = 1 -- lua is 1-based indexed

local pow = math.pow or function(x, y) return x ^ y end ---@diagnostic disable-line: deprecated
local sin = math.sin

local ffi = allegro5_lua.ffi

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
    ffi = require("ffi")
else
    ffi.cdef(cffi_lua_def)
    tonumber = ffi.tonumber
end

local intptr_t = function(cdata)
    return tonumber(ffi.cast("intptr_t", ffi.cast("void*", cdata)))
end

ffi.cdef(cdef)

local ThreadInfo = ffi.typeof("ThreadInfo")
local thread_info = ThreadInfo()


--[[ Resamping test. Probably should integreate into test_driver somehow --]]

local SAMPLES_PER_BUFFER = 1024

local N = 2

local frequency = (function()
    local frequency = {}
    for i = 1, N do
        frequency[i] = 0
    end
    return frequency
end)()
local samplepos = (function()
    local samplepos = {}
    for i = 1, N do
        samplepos[i] = 0
    end
    return samplepos
end)()
local stream = {}
local display

local function mainloop()
    thread_info.mutex = allegro5.al_create_mutex()
    if thread_info.mutex == nil then
        abort_example("Error creating mutex\n")
    end
    thread_info.cond = allegro5.al_create_cond()
    if thread_info.cond == nil then
        abort_example("Error creating cond\n")
    end

    local thread_start = lanes.gen("*", update_waveform_thread_func)
    local thread = thread_start(intptr_t(thread_info))

    local waveform = thread_info.waveform
    local pitch = 440
    local n = 0
    local redraw = false

    for i = 0, N - INDEX_BASE do
        frequency[i + INDEX_BASE] = 22050 * pow(2, i / N)
        stream[i + INDEX_BASE] = allegro5.al_create_audio_stream(4, SAMPLES_PER_BUFFER, frequency[i + INDEX_BASE],
            allegro5.ALLEGRO_AUDIO_DEPTH_FLOAT32, allegro5.ALLEGRO_CHANNEL_CONF_1)
        if not stream[i + INDEX_BASE] then
            abort_example("Could not create stream.\n")
        end

        if not allegro5.al_attach_audio_stream_to_mixer(stream[i + INDEX_BASE], allegro5.al_get_default_mixer()) then
            abort_example("Could not attach stream to mixer.\n")
        end
    end

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    for i = 0, N - INDEX_BASE do
        allegro5.al_register_event_source(queue,
            allegro5.al_get_audio_stream_event_source(stream[i + INDEX_BASE]))
    end
    if env.ALLEGRO_POPUP_EXAMPLES then
        if common.textlog then
            allegro5.al_register_event_source(queue, allegro5.al_get_native_text_log_event_source(common.textlog))
        end
    end

    log_printf("Generating %d sine waves of different sampling quality\n", N)
    log_printf("If Allegro's resampling is correct there should be little variation\n", N)

    local timer = allegro5.al_create_timer(1.0 / 60)
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    allegro5.al_start_timer(timer)
    while n < 60 * frequency[0 + INDEX_BASE] / SAMPLES_PER_BUFFER * N do
        if thread.status == "error" then
            error(thread[1])
        end

        local event = allegro5.ALLEGRO_EVENT()

        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_AUDIO_STREAM_FRAGMENT then
            for si = 0, N - INDEX_BASE do
                local buf = pointer_cast("float", allegro5.al_get_audio_stream_fragment(stream[si + INDEX_BASE]))
                if buf then
                    for i = 0, SAMPLES_PER_BUFFER - INDEX_BASE do
                        local t = samplepos[si + INDEX_BASE] / frequency[si + INDEX_BASE]
                        samplepos[si + INDEX_BASE] = samplepos[si + INDEX_BASE] + 1
                        buf[i] = sin(t * pitch * allegro5.ALLEGRO_PI * 2) / N
                    end

                    if not allegro5.al_set_audio_stream_fragment(stream[si + INDEX_BASE], buf) then
                        log_printf("Error setting stream fragment.\n")
                    end

                    n = n + 1
                    log_printf("%d", si)
                    if (n % 60) == 0 then
                        log_printf("\n")
                    end
                end
            end
        end

        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        end

        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN and
            event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
            break
        end

        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end

        if env.ALLEGRO_POPUP_EXAMPLES then
            if event.type == allegro5.ALLEGRO_EVENT_NATIVE_DIALOG_CLOSE then
                break
            end
        end

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            local c = allegro5.al_map_rgb(0, 0, 0)
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(1, 1, 1))

            for i = 0, 640 - INDEX_BASE do
                allegro5.al_draw_pixel(i, 50 + waveform[i] * 50, c)
            end

            allegro5.al_flip_display()
            redraw = false
        end
    end

    for si = 0, N - INDEX_BASE do
        allegro5.al_drain_audio_stream(stream[si + INDEX_BASE])
    end

    log_printf("\n")

    allegro5.al_destroy_event_queue(queue)

    allegro5.al_lock_mutex(thread_info.mutex)
    thread_info.stop_requested = true
    allegro5.al_broadcast_cond(thread_info.cond)
    allegro5.al_unlock_mutex(thread_info.mutex)
    thread:join()
end

local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_install_keyboard()

    open_log()

    display = allegro5.al_create_display(640, 100)
    if not display then
        abort_example("Could not create display.\n")
    end

    if not allegro5.al_install_audio() then
        abort_example("Could not init sound.\n")
    end
    allegro5.al_reserve_samples(N)

    mainloop()

    close_log(false)

    for i = 0, N - INDEX_BASE do
        allegro5.al_destroy_audio_stream(stream[i + INDEX_BASE])
    end
    allegro5.al_uninstall_audio()

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
