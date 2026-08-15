local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/BitmapResource.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local Debug = require("Debug")
local Resource = require("Resource").Resource

local debug_message = Debug.debug_message

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

---@class BitmapResource : Resource
---@field private bitmap? ALLEGRO_BITMAP
---@field private filename? string
---@overload fun(filename : string?): BitmapResource
local BitmapResource = common.class({
    __name = "BitmapResource",
}, Resource)
exports.BitmapResource = BitmapResource

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/BitmapResource.cpp
--]]

---@param self BitmapResource
function BitmapResource.destroy(self)
    if not self.bitmap then
        return
    end
    allegro5.al_destroy_bitmap(self.bitmap)
end

---@param self BitmapResource
---@return boolean
function BitmapResource.load(self)
    allegro5.al_set_new_bitmap_format(allegro5.ALLEGRO_PIXEL_FORMAT_ANY_WITH_ALPHA)
    allegro5.al_set_new_bitmap_flags(bit.bor(allegro5.ALLEGRO_MIN_LINEAR, allegro5.ALLEGRO_MAG_LINEAR))
    self.bitmap = allegro5.al_load_bitmap(self.filename)
    if not self.bitmap then
        debug_message("Error loading bitmap %s\n", self.filename)
    end
    return self.bitmap ~= 0
end

---@param self BitmapResource
---@return ALLEGRO_BITMAP?
function BitmapResource.get(self)
    return self.bitmap
end

---@param self BitmapResource
---@param filename string?
function BitmapResource.BitmapResource(self, filename)
    self.filename = filename
end

return exports
