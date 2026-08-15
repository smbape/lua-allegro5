local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/SmallBullet.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local Bullet = require("Bullet").Bullet
local Resource = require("Resource")


local RES_SMALLBULLET = Resource.RES_SMALLBULLET

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

---@class SmallBullet : Bullet
---@overload fun(x : number, y : number, angle : number, shooter? : Entity): SmallBullet
local SmallBullet = common.class({
    __name = "SmallBullet",
}, Bullet)
exports.SmallBullet = SmallBullet

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/SmallBullet.cpp
--]]

---@param self SmallBullet
---@param offx integer
---@param offy integer
function SmallBullet.render_at(self, offx, offy)
    allegro5.al_draw_rotated_bitmap(self.bitmap, self.radius, self.radius, offx + self.x, offy + self.y, 0.0, 0)
end

---@param self SmallBullet
---@param x number
---@param y number
---@param angle number
---@param shooter? Entity
function SmallBullet.SmallBullet(self, x, y, angle, shooter)
    Bullet.Bullet(self, x, y, 4, 0.5, angle, 600, 1, RES_SMALLBULLET, shooter)
end

return exports
