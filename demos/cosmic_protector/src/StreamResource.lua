local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/StreamResource.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local Debug = require("Debug")
local Resource = require("Resource").Resource

local debug_message = Debug.debug_message

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

---@class StreamResource : Resource
---@field private stream? ALLEGRO_AUDIO_STREAM
---@field private filename? string
---@overload fun(filename : string?): StreamResource
local StreamResource = common.class({
    __name = "StreamResource",
}, Resource)
exports.StreamResource = StreamResource

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/StreamResource.cpp
--]]

---@param self StreamResource
function StreamResource.destroy(self)
    if not self.stream then
        return
    end
    allegro5.al_destroy_audio_stream(self.stream)
    self.stream = nil
end

---@param self StreamResource
---@return boolean
function StreamResource.load(self)
    if not allegro5.al_is_audio_installed() then
        debug_message("Skipped loading stream %s\n", self.filename)
        return true
    end

    self.stream = allegro5.al_load_audio_stream(self.filename, 4, 1024)
    if not self.stream then
        debug_message("Error creating stream\n")
        return false
    end

    allegro5.al_set_audio_stream_playing(self.stream, false)
    allegro5.al_set_audio_stream_playmode(self.stream, allegro5.ALLEGRO_PLAYMODE_LOOP)
    allegro5.al_attach_audio_stream_to_mixer(self.stream, allegro5.al_get_default_mixer())

    return true
end

---@param self StreamResource
---@return ALLEGRO_AUDIO_STREAM?
function StreamResource.get(self)
    return self.stream
end

---@param self StreamResource
---@param filename? string
function StreamResource.StreamResource(self, filename)
    self.stream = nil
    self.filename = filename
end

return exports
