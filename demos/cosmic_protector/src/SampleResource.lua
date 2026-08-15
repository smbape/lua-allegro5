local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/SampleResource.hpp
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

---@class SampleResource : Resource
---@field private sample_data? ALLEGRO_SAMPLE
---@field private filename? string
---@overload fun(filename : string?): SampleResource
local SampleResource = common.class({
    __name = "SampleResource",
}, Resource)
exports.SampleResource = SampleResource

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/SampleResource.cpp
--]]

---@param self SampleResource
function SampleResource.destroy(self)
    allegro5.al_destroy_sample(self.sample_data)
    self.sample_data = nil
end

---@param self SampleResource
---@return boolean
function SampleResource.load(self)
    if not allegro5.al_is_audio_installed() then
        debug_message("Skipped loading sample %s\n", self.filename)
        return true
    end

    self.sample_data = allegro5.al_load_sample(self.filename)
    if not self.sample_data then
        debug_message("Error loading sample %s\n", self.filename)
        return false
    end

    return true
end

---@param self SampleResource
---@return ALLEGRO_SAMPLE?
function SampleResource.get(self)
    return self.sample_data
end

---@param self SampleResource
---@param filename? string
function SampleResource.SampleResource(self, filename)
    self.sample_data = nil
    self.filename = filename
end

return exports
