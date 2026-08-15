local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/FontResource.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local Resource = require("Resource").Resource

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

---@class FontResource : Resource
---@field private font? ALLEGRO_FONT
---@field private filename? string
---@overload fun(filename : string?): FontResource
local FontResource = common.class({
    __name = "FontResource",
}, Resource)
exports.FontResource = FontResource

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/FontResource.cpp
--]]

---@param self FontResource
function FontResource.destroy(self)
    allegro5.al_destroy_font(self.font)
end

---@param self FontResource
---@return boolean
function FontResource.load(self)
    self.font = allegro5.al_load_font(self.filename, 0, 0)
    return self.font ~= nil
end

---@param self FontResource
---@return ALLEGRO_FONT?
function FontResource.get(self)
    return self.font
end

---@param self FontResource
---@param filename string?
function FontResource.FontResource(self, filename)
    self.filename = filename
end

return exports
