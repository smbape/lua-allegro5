local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/LargeBullet.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local Bullet = require("Bullet").Bullet
local Resource = require("Resource")

local RES_LARGEBULLET = Resource.RES_LARGEBULLET

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

---@class LargeBullet : Bullet
---@overload fun(x : number, y : number, angle : number, shooter? : Entity): LargeBullet
local LargeBullet = common.class({
    __name = "LargeBullet",
}, Bullet)
exports.LargeBullet = LargeBullet

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/LargeBullet.cpp
--]]

---@param self LargeBullet
---@param offx integer
---@param offy integer
function LargeBullet.render_at(self, offx, offy)
    allegro5.al_draw_rotated_bitmap(self.bitmap, self.radius, self.radius, offx + self.x, offy + self.y,
        self.angle + (allegro5.ALLEGRO_PI / 2), 0)
end

---@param self LargeBullet
---@param x number
---@param y number
---@param angle number
---@param shooter? Entity
function LargeBullet.LargeBullet(self, x, y, angle, shooter)
    Bullet.Bullet(self, x, y, 6, 0.6, angle, 600, 2, RES_LARGEBULLET, shooter)
end

return exports
