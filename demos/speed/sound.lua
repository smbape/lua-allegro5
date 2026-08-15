--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/speed/sound.c
--]]

---@class ThreadInfo
---@field no_music boolean
---@field music_timer? ALLEGRO_TIMER
---@field ping? ALLEGRO_SAMPLE
---@field sine? ALLEGRO_SAMPLE
---@field square? ALLEGRO_SAMPLE
---@field saw? ALLEGRO_SAMPLE
---@field bd? ALLEGRO_SAMPLE
---@field snare? ALLEGRO_SAMPLE
---@field hihat? ALLEGRO_SAMPLE
---@field ping_vol integer
---@field ping_freq integer
---@field ping_count integer
---@field ping_timer? ALLEGRO_TIMER
---@field mutex? ALLEGRO_MUTEX
---@field cond? ALLEGRO_COND
---@field stop_requested boolean

local cdef = [[
typedef struct ThreadInfo {
    bool no_music;

    ALLEGRO_TIMER *music_timer;

    ALLEGRO_SAMPLE *ping;
    ALLEGRO_SAMPLE *sine;
    ALLEGRO_SAMPLE *square;
    ALLEGRO_SAMPLE *saw;
    ALLEGRO_SAMPLE *bd;
    ALLEGRO_SAMPLE *snare;
    ALLEGRO_SAMPLE *hihat;
    int ping_vol;
    int ping_freq;
    int ping_count;
    ALLEGRO_TIMER *ping_timer;

    ALLEGRO_MUTEX *mutex;
    ALLEGRO_COND *cond;
    bool stop_requested;
} ThreadInfo;
]]

local cffi_lua_def = [[
    typedef struct ALLEGRO_TIMER ALLEGRO_TIMER;
    typedef struct ALLEGRO_SAMPLE ALLEGRO_SAMPLE;
    typedef struct ALLEGRO_MUTEX ALLEGRO_MUTEX;
    typedef struct ALLEGRO_COND ALLEGRO_COND;
]]

local INDEX_BASE = 1 -- lua is 1-based indexed

local function sound_update_proc(arg)
    ---@param x integer
    ---@return number
    local function PAN(x)
        return (x - 128) / 128.0
    end

    --[[ music player state --]]
    local NUM_PARTS = 4

    local allegro5_lua = require("allegro5_lua")
    local allegro5 = allegro5_lua.allegro5
    local common = require("examples.common")
    local a4_aux = require("a4_aux")
    local sound_data = require("sound_data")

    local get_stored_pointer = common.get_stored_pointer

    local ffi = allegro5_lua.ffi ---@diagnostic disable-line: no-unknown, undefined-field

    if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
        allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
        ffi = require("ffi") ---@diagnostic disable-line: no-unknown
    else
        ffi.cdef(cffi_lua_def)
    end

    ffi.cdef(cdef)

    local play_sample = a4_aux.play_sample

    local init_music = sound_data.init_music
    local shutdown_music = sound_data.shutdown_music

    local info = ffi.cast("ThreadInfo*", arg) ---@type ThreadInfo

    local part_ptr = sound_data.part_ptr
    local part_pos_offset = sound_data.part_pos_offset
    local part_pos = sound_data.part_pos
    local part_time = sound_data.part_time
    local freq_table = sound_data.freq_table
    local part_voice = sound_data.part_voice

    local ping = info.ping
    local sine = info.sine
    local square = info.square
    local saw = info.saw
    local bd = info.bd
    local snare = info.snare
    local hihat = info.hihat

    if not info.no_music then
        init_music(sine, square, saw, bd)
    end

    --[[ the main music player function --]]
    local function music_player()
        local note = 0 ---@type integer

        for i = 0, NUM_PARTS - INDEX_BASE do
            if part_time[i + INDEX_BASE] <= 0 then
                note = part_pos[i + INDEX_BASE][0 + INDEX_BASE + part_pos_offset[i + INDEX_BASE]]
                part_time[i + INDEX_BASE] = part_pos[i + INDEX_BASE][1 + INDEX_BASE + part_pos_offset[i + INDEX_BASE]]

                allegro5.al_stop_sample_instance(part_voice[i + INDEX_BASE])

                if i == 3 then
                    if note == 1 then
                        allegro5.al_set_sample(part_voice[i + INDEX_BASE], bd)
                        allegro5.al_set_sample_instance_pan(part_voice[i + INDEX_BASE], PAN(128))
                    elseif note == 2 then
                        allegro5.al_set_sample(part_voice[i + INDEX_BASE], snare)
                        allegro5.al_set_sample_instance_pan(part_voice[i + INDEX_BASE], PAN(160))
                    else
                        allegro5.al_set_sample(part_voice[i + INDEX_BASE], hihat)
                        allegro5.al_set_sample_instance_pan(part_voice[i + INDEX_BASE], PAN(96))
                    end

                    allegro5.al_play_sample_instance(part_voice[i + INDEX_BASE])
                else
                    if note > 0 then
                        allegro5.al_set_sample_instance_speed(part_voice[i + INDEX_BASE],
                            freq_table[note + INDEX_BASE] / 22050.0)
                        allegro5.al_play_sample_instance(part_voice[i + INDEX_BASE])
                    end
                end

                part_pos_offset[i + INDEX_BASE] = part_pos_offset[i + INDEX_BASE] + 2
                if part_pos[i + INDEX_BASE][1 + INDEX_BASE + part_pos_offset[i + INDEX_BASE]] == 0 then
                    part_pos_offset[i + INDEX_BASE] = 0
                    part_pos[i + INDEX_BASE] = part_ptr[i + INDEX_BASE]
                end
            end

            part_time[i + INDEX_BASE] = part_time[i + INDEX_BASE] - 1
        end
    end

    ---@return boolean
    local function ping_proc()
        info.ping_freq = math.floor(info.ping_freq * 4 / 3)

        play_sample(ping, info.ping_vol, 128, info.ping_freq, false)

        info.ping_count = info.ping_count - 1
        if info.ping_count == 0 then
            return false
        end

        return true
    end

    local music_timer = info.music_timer
    local ping_timer = info.ping_timer

    local event = allegro5.ALLEGRO_EVENT()

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(ping_timer))
    if music_timer ~= nil then
        allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(music_timer))
    end

    while true do
        allegro5.al_lock_mutex(info.mutex)
        if info.stop_requested then
            break
        end

        if allegro5.al_wait_for_event_timed(queue, event, 0.25) then
            local source = get_stored_pointer(event.any.source)
            if source == get_stored_pointer(music_timer) then
                music_player()
            end

            if source == get_stored_pointer(ping_timer) then
                if not ping_proc() then
                    allegro5.al_stop_timer(ping_timer)
                end
            end
        end

        allegro5.al_unlock_mutex(info.mutex)
    end

    allegro5.al_destroy_event_queue(queue)

    if not info.no_music then
        shutdown_music()
    end
end

local exports = {}


local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local a4_aux = require("a4_aux")
local lanes = require("lanes")
local speed = require("speed")

local pointer_cast = common.pointer_cast
local rand = common.rand

local fmod = math.fmod
local sin = math.sin

local ffi = allegro5_lua.ffi

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
    ffi = require("ffi")
else
    ffi.cdef(cffi_lua_def)
    tonumber = ffi.tonumber
end

ffi.cdef(cdef)

local ThreadInfo = ffi.typeof("ThreadInfo")

local intptr_t = function(cdata)
    return tonumber(ffi.cast("intptr_t", ffi.cast("void*", cdata)))
end

local thread_info = ThreadInfo()

local create_sample_u8 = a4_aux.create_sample_u8
local play_sample = a4_aux.play_sample

--[[
 -    SPEED - by Shawn Hargreaves, 1999
 -
 -    This file is quite possibly the most entirely pointless piece of
 -    code that I have ever written. I didn't want to include any external
 -    data, you see, so everything has to work entirely from C source,
 -    which means generating all the sounds from code. I don't know why
 -    I'm bothering, because this probably won't sound too good :-)
 --]]

local M_PI = 3.14159265358979323846



--[[ generated sample waveforms --]]
local zap ---@type ALLEGRO_SAMPLE?
local bang ---@type ALLEGRO_SAMPLE?
local bigbang ---@type ALLEGRO_SAMPLE?
local ping ---@type ALLEGRO_SAMPLE?
local sine ---@type ALLEGRO_SAMPLE?
local square ---@type ALLEGRO_SAMPLE?
local saw ---@type ALLEGRO_SAMPLE?
local bd ---@type ALLEGRO_SAMPLE?
local snare ---@type ALLEGRO_SAMPLE?
local hihat ---@type ALLEGRO_SAMPLE?



local function RAND()
    return (bit.band(rand(), 255) / 255.0) - 0.5
end



local music_timer ---@type ALLEGRO_TIMER?



--[[ this code is sick --]]
local function init_music()
    local vol, val = 0, 0 ---@type number, number
    local p ---@type { [integer] : integer }

    if not allegro5.al_is_audio_installed() then
        return
    end

    --[[ sine waves (one straight and one with oscillator sync) for the bass --]]
    sine = create_sample_u8(22050, 64)
    p = pointer_cast("char", allegro5.al_get_sample_data(sine)) ---@type { [integer] : integer }

    for i = 0, 64 - INDEX_BASE do
        p[i] = math.floor(128 + (sin(i * M_PI / 32.0) + sin(i * M_PI / 12.0)) * 8.0)
    end

    --[[ square wave for melody #1 --]]
    square = create_sample_u8(22050, 64)
    p = pointer_cast("char", allegro5.al_get_sample_data(square)) ---@type { [integer] : integer }

    for i = 0, 64 - INDEX_BASE do
        p[i] = (function() if (i < 32) then return 120 else return 136 end end)()
    end

    --[[ saw wave for melody #2 --]]
    saw = create_sample_u8(22050, 64)
    p = pointer_cast("char", allegro5.al_get_sample_data(saw)) ---@type { [integer] : integer }

    for i = 0, 64 - INDEX_BASE do
        p[i] = 120 + math.floor(bit.band(i * 4, 255) / 16)
    end

    --[[ bass drum --]]
    bd = create_sample_u8(22050, 1024)
    p = pointer_cast("char", allegro5.al_get_sample_data(bd)) ---@type { [integer] : integer }

    for i = 0, 1024 - INDEX_BASE do
        vol = (1024 - i) / 16.0
        p[i] = math.floor(128 + (sin(i / 48.0) + sin(i / 32.0)) * vol)
    end

    --[[ snare drum --]]
    snare = create_sample_u8(22050, 3072)
    p = pointer_cast("char", allegro5.al_get_sample_data(snare)) ---@type { [integer] : integer }

    val = 0

    for i = 0, 3072 - INDEX_BASE do
        vol = (3072 - i) / 24.0
        val = (val * 0.9) + (RAND() * 0.1)
        p[i] = math.floor(128 + val * vol)
    end

    --[[ hihat --]]
    hihat = create_sample_u8(22050, 1024)
    p = pointer_cast("char", allegro5.al_get_sample_data(hihat)) ---@type { [integer] : integer }

    for i = 0, 1024 - INDEX_BASE do
        vol = (1024 - i) / 192.0
        p[i] = math.floor(128 + (sin(i / 4.2) + RAND()) * vol)
    end

    music_timer = allegro5.al_create_timer(allegro5.ALLEGRO_BPS_TO_SECS(22))
end



--[[ timer callback for playing ping samples --]]
-- local ping_vol = 0 ---@type integer
-- local ping_freq = 0 ---@type integer
-- local ping_count = 0 ---@type integer
local ping_timer ---@type ALLEGRO_TIMER?



--[[ thread to keep the music playing and the pings pinging --]]
local sound_update_thread



--[[ initialises the sound system --]]
local function init_sound()
    if not allegro5.al_is_audio_installed() then
        return
    end

    thread_info.mutex = allegro5.al_create_mutex()
    if not thread_info.mutex then
        error("Error creating mutex")
    end

    thread_info.cond = allegro5.al_create_cond()
    if not thread_info.cond then
        error("Error creating cond")
    end

    thread_info.stop_requested = false

    local p ---@type { [integer] : integer }

    --[[ zap (firing sound) consists of multiple falling saw waves --]]
    local len = 8192 ---@type integer
    zap = create_sample_u8(22050, len)

    p = pointer_cast("char", allegro5.al_get_sample_data(zap)) ---@type { [integer] : integer }

    local osc1 = 0 ---@type number
    local freq1 = 0.02

    local osc2 = 0 ---@type number
    local freq2 = 0.025

    for i = 0, len - INDEX_BASE do
        local vol = (len - i) / len * 127

        p[i] = math.floor(128 + (fmod(osc1, 1) + fmod(osc2, 1) - 1) * vol)

        osc1 = osc1 + (freq1) ---@type number
        freq1 = freq1 - (0.000001)

        osc2 = osc2 + (freq2) ---@type number
        freq2 = freq2 - (0.00000125)
    end

    --[[ bang (explosion) consists of filtered noise --]]
    len = 8192
    bang = create_sample_u8(22050, len)

    p = pointer_cast("char", allegro5.al_get_sample_data(bang)) ---@type { [integer] : integer }

    local val = 0 ---@type number

    for i = 0, len - INDEX_BASE do
        local vol = (len - i) / len * 255
        val = (val * 0.75) + (RAND() * 0.25)
        p[i] = math.floor(128 + val * vol)
    end

    --[[ big bang (explosion) consists of noise plus rumble --]]
    len = 24576
    bigbang = create_sample_u8(11025, len)

    p = pointer_cast("char", allegro5.al_get_sample_data(bigbang)) ---@type { [integer] : integer }

    val = 0

    osc1 = 0
    osc2 = 0

    for i = 0, len - INDEX_BASE do
        local vol = (len - i) / len * 128

        local f = 0.5 + (i / len * 0.4)
        val = (val * f) + (RAND() * (1 - f))

        p[i] = math.floor(128 + (val + (sin(osc1) + sin(osc2)) / 4) * vol)

        osc1 = osc1 + (0.03)
        osc2 = osc2 + (0.04)
    end

    --[[ ping consists of two sine waves --]]
    len = 8192
    ping = create_sample_u8(22050, len)

    p = pointer_cast("char", allegro5.al_get_sample_data(ping)) ---@type { [integer] : integer }

    osc1 = 0 ---@type number
    osc2 = 0 ---@type number

    for i = 0, len - INDEX_BASE do
        local vol = (len - i) / len * 31

        p[i] = math.floor(128 + (sin(osc1) + sin(osc2) - 1) * vol)

        osc1 = osc1 + (0.2)
        osc2 = osc2 + (0.3)
    end

    ping_timer = allegro5.al_create_timer(0.3)

    --[[ set up my lurvely music player :-) --]]
    if not speed.no_music then
        init_music()
        allegro5.al_start_timer(music_timer)
    end

    thread_info.no_music = speed.no_music

    thread_info.music_timer = music_timer

    thread_info.ping = ping
    thread_info.sine = sine
    thread_info.square = square
    thread_info.saw = saw
    thread_info.bd = bd
    thread_info.snare = snare
    thread_info.hihat = hihat
    thread_info.ping_vol = 0
    thread_info.ping_freq = 0
    thread_info.ping_count = 0
    thread_info.ping_timer = ping_timer

    local thread_start = lanes.gen("*", sound_update_proc)
    sound_update_thread = thread_start(intptr_t(thread_info))
end
exports.init_sound = init_sound


local function check_sound_error()
    if sound_update_thread.status == "error" then
        error(sound_update_thread[1])
    end
end
exports.check_sound_error = check_sound_error


--[[ closes down the sound system --]]
local function shutdown_sound()
    if not allegro5.al_is_audio_installed() then
        return
    end

    --[[ Set the flag to stop the thread.  The thread might be waiting on a
   - condition variable, so signal the condition to force it to wake up.
   --]]
    allegro5.al_lock_mutex(thread_info.mutex)
    thread_info.stop_requested = true
    allegro5.al_broadcast_cond(thread_info.cond)
    allegro5.al_unlock_mutex(thread_info.mutex)

    --[[ al_destroy_thread() implicitly joins the thread, so this call is not
   - strictly necessary.
   --]]
    sound_update_thread:join()

    allegro5.al_destroy_timer(ping_timer)

    allegro5.al_stop_samples()

    allegro5.al_destroy_sample(zap)
    allegro5.al_destroy_sample(bang)
    allegro5.al_destroy_sample(bigbang)
    allegro5.al_destroy_sample(ping)

    if not speed.no_music then
        allegro5.al_destroy_timer(music_timer)

        allegro5.al_destroy_sample(sine)
        allegro5.al_destroy_sample(square)
        allegro5.al_destroy_sample(saw)
        allegro5.al_destroy_sample(bd)
        allegro5.al_destroy_sample(snare)
        allegro5.al_destroy_sample(hihat)
    end
end
exports.shutdown_sound = shutdown_sound



--[[ plays a shoot sound effect --]]
local function sfx_shoot()
    if allegro5.al_is_audio_installed() then
        play_sample(zap, 64, 128, 1000, false)
    end
end
exports.sfx_shoot = sfx_shoot



--[[ plays an alien explosion sound effect --]]
local function sfx_explode_alien()
    if allegro5.al_is_audio_installed() then
        play_sample(bang, 192, 128, 1000, false)
    end
end
exports.sfx_explode_alien = sfx_explode_alien



--[[ plays a block explosion sound effect --]]
local function sfx_explode_block()
    if allegro5.al_is_audio_installed() then
        play_sample(bang, 224, 128, 400, false)
    end
end
exports.sfx_explode_block = sfx_explode_block



--[[ plays a player explosion sound effect --]]
local function sfx_explode_player()
    if allegro5.al_is_audio_installed() then
        play_sample(bigbang, 255, 128, 1000, false)
    end
end
exports.sfx_explode_player = sfx_explode_player



--[[ plays a ping sound effect --]]
---@param times integer
local function sfx_ping(times)
    if not allegro5.al_is_audio_installed() then
        return
    end

    if times then
        if times > 1 then
            thread_info.ping_vol = 255
            thread_info.ping_freq = 500
        else
            thread_info.ping_vol = 128
            thread_info.ping_freq = 1000
        end

        thread_info.ping_count = times

        play_sample(ping, thread_info.ping_vol, 128, thread_info.ping_freq, false)

        allegro5.al_start_timer(ping_timer)
    else
        play_sample(ping, 255, 128, 500, false)
    end
end
exports.sfx_ping = sfx_ping

return exports
