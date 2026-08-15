#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_mixer_pp.c
--]]

local cdef = [[
typedef struct ThreadInfo {
    float rms_l;
    float rms_r;
    ALLEGRO_MIXER *mixer;
    ALLEGRO_MUTEX *mutex;
    ALLEGRO_COND *cond;
    bool stop_requested;
} ThreadInfo;
]]

local cffi_lua_def = [[
    typedef struct ALLEGRO_MIXER ALLEGRO_MIXER;
    typedef struct ALLEGRO_MUTEX ALLEGRO_MUTEX;
    typedef struct ALLEGRO_COND ALLEGRO_COND;
]]

local function update_meter_thread_func(arg)
    local allegro5_lua = require("allegro5_lua")
    local allegro5 = allegro5_lua.allegro5
    local common = require("common")

    local pointer_cast = common.pointer_cast

    local sqrt = math.sqrt

    local ffi = allegro5_lua.ffi

    if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
        allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
        ffi = require("ffi")
    else
        ffi.cdef(cffi_lua_def)
    end

    ffi.cdef(cdef)

    local info = ffi.cast("ThreadInfo*", arg)
    local mixer = info.mixer

    local function update_meter(buf, samples, data)
        local fbuf = pointer_cast("float", buf)
        local sum_l = 0.0
        local sum_r = 0.0

        for i = 1, samples do
            sum_l = sum_l + (fbuf[0] * fbuf[0])
            sum_r = sum_r + (fbuf[1] * fbuf[1])
            fbuf = fbuf + (2)
        end

        info.rms_l = sqrt(sum_l / samples)
        info.rms_r = sqrt(sum_r / samples)
    end

    allegro5.al_set_mixer_postprocess_callback(mixer, update_meter, nil)

    allegro5.al_lock_mutex(info.mutex)
    info.stop_requested = false
    while not info.stop_requested do
        allegro5.al_wait_cond(info.cond, info.mutex)
    end

    allegro5.al_set_mixer_postprocess_callback(mixer, nil, nil)
end

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")
local lanes = require("lanes")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local startswith = common.startswith

local log10 = math.log10 or function(x) return math.log(x, 10) end ---@diagnostic disable-line: deprecated

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

--[[
 -    Example program for the Allegro library, by Peter Wang.
 -
 -    This program demonstrates a simple use of mixer postprocessing callbacks.
 --]]

local FPS = 60

local display
local dbuf
local bmp
local theta = 0

local function draw()
    local sw = allegro5.al_get_bitmap_width(bmp)
    local sh = allegro5.al_get_bitmap_height(bmp)
    local dw = allegro5.al_get_bitmap_width(dbuf)
    local dh = allegro5.al_get_bitmap_height(dbuf)
    local dx = dw / 2.0
    local dy = dh / 2.0
    local db_l = 0
    local db_r = 0
    local db = 0
    local scale = 0
    local disp = 0

    local rms_l = thread_info.rms_l
    local rms_r = thread_info.rms_r

    --[[ Whatever looks okay. --]]
    if rms_l > 0.0 and rms_r > 0.0 then
        db_l = 20 * log10(rms_l / 20e-6)
        db_r = 20 * log10(rms_r / 20e-6)
        db = (db_l + db_r) / 2.0
        scale = db / 20.0
        disp = (rms_l + rms_r) * 200.0
    else
        disp = 0.0; scale = disp; db = scale; db_r = db; db_l = db_r
    end

    allegro5.al_set_target_bitmap(dbuf)
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_INVERSE_ALPHA)
    allegro5.al_draw_filled_rectangle(0, 0, allegro5.al_get_bitmap_width(dbuf), allegro5.al_get_bitmap_height(dbuf),
        allegro5.al_map_rgba_f(0.8, 0.3, 0.1, 0.06))
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
    allegro5.al_draw_tinted_scaled_rotated_bitmap(bmp,
        allegro5.al_map_rgba_f(0.8, 0.3, 0.1, 0.2),
        sw / 2.0, sh / 2.0, dx, dy - disp, scale, scale, theta, 0)

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
    allegro5.al_set_target_backbuffer(display)
    allegro5.al_draw_bitmap(dbuf, 0, 0, 0)

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_INVERSE_ALPHA)
    allegro5.al_draw_line(10, dh - db_l, 10, dh, allegro5.al_map_rgb_f(1, 0.6, 0.2), 6)
    allegro5.al_draw_line(20, dh - db_r, 20, dh, allegro5.al_map_rgb_f(1, 0.6, 0.2), 6)

    allegro5.al_flip_display()

    theta = theta - ((rms_l + rms_r) * 0.1)
end

local function main_loop()
    thread_info.mutex = allegro5.al_create_mutex()
    if thread_info.mutex == nil then
        abort_example("Error creating mutex\n")
    end
    thread_info.cond = allegro5.al_create_cond()
    if thread_info.cond == nil then
        abort_example("Error creating cond\n")
    end

    local thread_start = lanes.gen("*", update_meter_thread_func)
    local thread = thread_start(intptr_t(thread_info))

    local event = allegro5.ALLEGRO_EVENT()
    local redraw = true

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    theta = 0.0

    while true do
        if thread.status == "error" then
            error(thread[1])
        end

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            draw()
            redraw = false
        end

        if not allegro5.al_wait_for_event_timed(queue, event, 1.0 / FPS) then
            redraw = true
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN and
            event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
            break
        end
    end

    allegro5.al_destroy_event_queue(queue)

    allegro5.al_lock_mutex(thread_info.mutex)
    thread_info.stop_requested = true
    allegro5.al_broadcast_cond(thread_info.cond)
    allegro5.al_unlock_mutex(thread_info.mutex)
    thread:join()
end

local function main(argv)
    local argc = #argv

    local filename = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/../../demos/cosmic_protector/data/sfx/title_music.ogg"

    if argc >= 1 then
        filename = argv[1]

        if startswith(filename, "data/") then
            filename = env.ALLEGRO_EXAMPLES_DATA_PATH .. filename:sub(string.len("data") + 1)
        end
    end

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_init_primitives_addon()
    allegro5.al_init_image_addon()
    allegro5.al_init_acodec_addon()
    init_platform_specific()

    allegro5.al_install_keyboard()

    display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Could not create display.\n")
    end

    dbuf = allegro5.al_create_bitmap(640, 480)

    bmp = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not bmp then
        abort_example("Could not load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx\n")
    end

    if not allegro5.al_install_audio() then
        abort_example("Could not init sound.\n")
    end

    local voice = allegro5.al_create_voice(44100, allegro5.ALLEGRO_AUDIO_DEPTH_INT16,
        allegro5.ALLEGRO_CHANNEL_CONF_2)
    if not voice then
        abort_example("Could not create voice.\n")
    end

    local mixer = allegro5.al_create_mixer(44100, allegro5.ALLEGRO_AUDIO_DEPTH_FLOAT32,
        allegro5.ALLEGRO_CHANNEL_CONF_2)
    if not mixer then
        abort_example("Could not create mixer.\n")
    end

    if not allegro5.al_attach_mixer_to_voice(mixer, voice) then
        abort_example("al_attach_mixer_to_voice failed.\n")
    end

    local stream = allegro5.al_load_audio_stream(filename, 4, 2048)
    if not stream then
        --[[ On Android we only pack this into the APK. --]]
        filename = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/welcome.wav"
        stream = allegro5.al_load_audio_stream(filename, 4, 2048)
    end
    if not stream then
        abort_example("Could not load '%s'\n", filename)
    end

    allegro5.al_set_audio_stream_playmode(stream, allegro5.ALLEGRO_PLAYMODE_LOOP)
    allegro5.al_attach_audio_stream_to_mixer(stream, mixer)

    thread_info.mixer = mixer

    main_loop()

    allegro5.al_destroy_audio_stream(stream)
    allegro5.al_destroy_mixer(mixer)
    allegro5.al_destroy_voice(voice)
    allegro5.al_uninstall_audio()

    allegro5.al_destroy_bitmap(dbuf)
    allegro5.al_destroy_bitmap(bmp)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
