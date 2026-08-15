local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/music.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local _global = require("global")

local rand = common.rand

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local stop_music ---@type function

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/music.c
--]]

local currently_playing = -1 ---@type integer
local volume_music, volume_sound = 1, 1 ---@type number

---@param v number
local function set_music_volume(v)
    volume_music = v
    if currently_playing == -1 then
        return
    end
    allegro5.al_set_audio_stream_gain(_global.demo_data[currently_playing + INDEX_BASE].dat, volume_music)
end
exports.set_music_volume = set_music_volume

---@param v number
local function set_sound_volume(v)
    volume_sound = v
end
exports.set_sound_volume = set_sound_volume

---@param id integer
---@param loop boolean
local function play_music(id, loop)
    if not _global.demo_data[id + INDEX_BASE].dat then
        return
    end
    if id == currently_playing then
        return
    end
    stop_music()

    allegro5.al_set_audio_stream_playmode(_global.demo_data[id + INDEX_BASE].dat,
        (function() if loop then return allegro5.ALLEGRO_PLAYMODE_LOOP else return allegro5.ALLEGRO_PLAYMODE_ONCE end end)())

    allegro5.al_set_audio_stream_gain(_global.demo_data[id + INDEX_BASE].dat, volume_music)

    allegro5.al_attach_audio_stream_to_mixer(_global.demo_data[id + INDEX_BASE].dat,
        allegro5.al_get_default_mixer())
    allegro5.al_set_audio_stream_playing(_global.demo_data[id + INDEX_BASE].dat, true)

    currently_playing = id
end
exports.play_music = play_music


stop_music = function()
    if currently_playing == -1 then
        return
    end
    allegro5.al_set_audio_stream_playing(_global.demo_data[currently_playing + INDEX_BASE].dat, false)
    currently_playing = -1
end
exports.stop_music = stop_music


---@param s ALLEGRO_SAMPLE
---@param vol integer
---@param pan integer
---@param freq integer
---@param loop boolean
local function play_sound(s, vol, pan, freq, loop)
    ---@type integer
    local playmode = (function()
        if loop then
            return allegro5.ALLEGRO_PLAYMODE_LOOP
        else
            return allegro5.ALLEGRO_PLAYMODE_ONCE
        end
    end)()
    if not s then
        return
    end
    if freq < 0 then
        freq = 1000 + rand() % (-freq) + math.floor(freq / 2) ---@type integer
    end

    allegro5.al_play_sample(s, volume_sound * vol / 255.0,
        (pan - 128) / 128.0, freq / 1000.0, playmode, nil)
end
exports.play_sound = play_sound

---@param id integer
---@param vol integer
---@param pan integer
---@param freq integer
---@param loop boolean
local function play_sound_id(id, vol, pan, freq, loop)
    play_sound(_global.demo_data[id + INDEX_BASE].dat, vol, pan, freq, loop)
end
exports.play_sound_id = play_sound_id

return exports
