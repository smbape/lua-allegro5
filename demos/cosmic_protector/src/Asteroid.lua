local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/Asteroid.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local sound = require("sound")
local Entity = require("Entity").Entity
local Game = require("Game")
local Resource = require("Resource")
local ResourceManager = require("ResourceManager").ResourceManager

local randf = Game.randf

local my_play_sample = sound.my_play_sample

local RES_COLLISION = Resource.RES_COLLISION

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

---@class Asteroid : Entity
---@field protected da number
---@field protected angle number
---@field protected speed_x number
---@field protected speed_y number
---@field protected bitmap? ALLEGRO_BITMAP
---@overload fun(radius : number, bitmapID : integer): Asteroid
local Asteroid = common.class({
    __name = "Asteroid",
}, Entity)
exports.Asteroid = Asteroid

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/Asteroid.cpp
--]]

---@param self Asteroid
---@param x number
---@param y number
---@param speed_x number
---@param speed_y number
---@param da number
function Asteroid.init(self, x, y, speed_x, speed_y, da)
    self.x = x
    self.y = y
    self.speed_x = speed_x
    self.speed_y = speed_y
    self.da = da
end

---@param self Asteroid
---@param step integer
---@return boolean
function Asteroid.logic(self, step)
    self.angle = self.angle - (self.da * step)

    local p = self:getPlayerCollision()
    if p then
        self:explode()
        p:hit(1)
        my_play_sample(RES_COLLISION)
        return false
    end

    self.dx = self.speed_x * step
    self.dy = self.speed_y * step

    Entity.wrap(self)

    if not Entity.logic(self, step) then
        return false
    end

    return true
end

---@param self Asteroid
---@param offx integer
---@param offy integer
function Asteroid.render_at(self, offx, offy)
    allegro5.al_draw_rotated_bitmap(self.bitmap, self.radius, self.radius, offx + self.x, offy + self.y, self.angle, 0)
end

---@param self Asteroid
---@param radius number
---@param bitmapID integer
function Asteroid.Asteroid(self, radius, bitmapID)
    Entity.Entity(self)

    self.da = 0
    self.angle = 0
    self.speed_x = 0
    self.speed_y = 0

    self.radius = radius

    self.angle = randf(0.0, allegro5.ALLEGRO_PI * 2.0)

    local rm = ResourceManager.getInstance()
    self.bitmap = rm:getData(bitmapID) ---@type ALLEGRO_BITMAP?
end

---@param self Asteroid
function Asteroid.__destroy(self)
end

return exports
