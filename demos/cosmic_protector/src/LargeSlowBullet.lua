local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/LargeSlowBullet.hpp
--]]

local common = require("examples.common")
local LargeBullet = require("LargeBullet").LargeBullet

---@class LargeSlowBullet : LargeBullet
---@overload fun(x : number, y : number, angle : number, shooter? : Entity): LargeSlowBullet
local LargeSlowBullet = common.class({
    __name = "LargeSlowBullet",
}, LargeBullet)
exports.LargeSlowBullet = LargeSlowBullet

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/LargeSlowBullet.cpp
--]]

---@param self LargeSlowBullet
---@param x number
---@param y number
---@param angle number
---@param shooter? Entity
function LargeSlowBullet.LargeSlowBullet(self, x, y, angle, shooter)
    LargeBullet.LargeBullet(self, x, y, angle, shooter)
    self.speed = 0.20
    self.lifetime = self.lifetime + (1000)
    self.playerOnly = true
end

return exports
