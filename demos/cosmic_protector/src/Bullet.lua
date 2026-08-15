local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/Bullet.hpp
--]]

local common = require("examples.common")
local sound = require("sound")
local Entity = require("Entity").Entity
local Resource = require("Resource")
local ResourceManager = require("ResourceManager").ResourceManager

local cos = math.cos
local sin = math.sin

local my_play_sample = sound.my_play_sample

local RES_COLLISION = Resource.RES_COLLISION

---@class Bullet : Entity
---@field protected bitmap? ALLEGRO_BITMAP
---@field protected speed number
---@field protected angle number
---@field protected lifetime integer
---@field protected cosa number
---@field protected sina number
---@field protected shooter? Entity
---@field protected damage integer
---@field protected playerOnly boolean
---@overload fun(x : number, y : number, radius : number, speed : number, angle : number, lifetime : integer, damage : integer, bitmapID : integer, shooter? : Entity): Bullet
local Bullet = common.class({
    __name = "Bullet",
}, Entity)
exports.Bullet = Bullet

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/Bullet.cpp
--]]

---@param self Bullet
---@param step integer
---@return boolean
function Bullet.logic(self, step)
    self.lifetime = self.lifetime - (step)
    if self.lifetime <= 0 then
        return false
    end

    self.dx = self.speed * self.cosa * step
    self.dy = self.speed * self.sina * step

    local c ---@type Entity?
    if self.playerOnly then
        c = self:getPlayerCollision()
    else
        c = self:getAllCollision()
    end
    if c and c ~= self.shooter then
        c:hit(self.damage)
        my_play_sample(RES_COLLISION)
        return false
    end

    Entity.wrap(self)

    if not Entity.logic(self, step) then
        return false
    end

    return true
end

---@param self Bullet
---@param x number
---@param y number
---@param radius number
---@param speed number
---@param angle number
---@param lifetime integer
---@param damage integer
---@param bitmapID integer
---@param shooter? Entity
function Bullet.Bullet(self, x, y, radius, speed, angle, lifetime, damage, bitmapID, shooter)
    Entity.Entity(self)

    self.playerOnly = false

    self.x = x
    self.y = y
    self.radius = radius
    self.speed = speed
    self.angle = angle
    self.lifetime = lifetime
    self.shooter = shooter
    self.damage = damage

    self.cosa = cos(angle)
    self.sina = sin(angle)

    local rm = ResourceManager.getInstance()
    self.bitmap = rm:getData(bitmapID) ---@type ALLEGRO_BITMAP?

    self.isDestructable = false
end

function Bullet.__destroy(self)
end

return exports
