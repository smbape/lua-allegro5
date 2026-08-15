local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/Entity.hpp
--]]

local common = require("examples.common")
local collision = require("collision")
local cosmic_protector = require("cosmic_protector")
local logic = require("logic")
local sound = require("sound")
local Resource = require("Resource")
local ResourceManager = require("ResourceManager").ResourceManager

local Explosion ---@class Explosion
local PowerUp ---@class PowerUp
exports.init = function()
    Explosion = require("Explosion").Explosion ---@diagnostic disable-line: cast-local-type
    PowerUp = require("PowerUp").PowerUp ---@diagnostic disable-line: cast-local-type
end

local checkCircleCollision = collision.checkCircleCollision

local BB_H = cosmic_protector.BB_H
local BB_W = cosmic_protector.BB_W

local entities = logic.entities
local new_entities = logic.new_entities

local my_play_sample = sound.my_play_sample

local RES_BIGEXPLOSION = Resource.RES_BIGEXPLOSION
local RES_PLAYER = Resource.RES_PLAYER
local RES_SMALLEXPLOSION = Resource.RES_SMALLEXPLOSION

exports.ENTITY_LARGE_ASTEROID = 0
exports.ENTITY_SMALL_ASTEROID = 1

---@class Entity
---@field protected x number
---@field protected y number
---@field protected radius number
---@field protected dx number
---@field protected dy number
---@field protected isDestructable boolean
---@field protected hp integer
---@field protected powerup integer
---@field protected hilightCount integer
---@field protected points integer
---@field protected ufo boolean
---@overload fun(): Entity
local Entity = common.class({
    __name = "Entity",
})
exports.Entity = Entity

---@param self Entity
function Entity.__destroy(self)
end

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/Entity.cpp
--]]

---@param self Entity
---@param step integer
---@return boolean
function Entity.logic(self, step)
    if self.hp <= 0 then
        self:spawn()
        local rm = ResourceManager.getInstance()
        local p = rm:getData(RES_PLAYER) ---@type Player
        p:addScore(self.points)
        return false
    end

    if self.hilightCount > 0 then
        self.hilightCount = self.hilightCount - (step)
    end

    return true
end

---@param self Entity
---@return number
function Entity.getX(self)
    return self.x
end

---@param self Entity
---@return number
function Entity.getY(self)
    return self.y
end

---@param self Entity
---@return number
function Entity.getRadius(self)
    return self.radius
end

---@param self Entity
---@return boolean
function Entity.getDestructable(self)
    return self.isDestructable
end

---@param self Entity
---@return boolean
function Entity.isHighlighted(self)
    return self.hilightCount > 0
end

---@param self Entity
---@return boolean
function Entity.isUFO(self)
    return self.ufo
end

---@param self Entity
---@param _type integer
function Entity.setPowerUp(self, _type)
    self.powerup = _type
end

---@param self Entity
function Entity.wrap(self)
    self.x = self.x + (self.dx)
    self.y = self.y + (self.dy)
    if self.x < 0 then
        self.x = self.x + (BB_W)
    end
    if self.x >= BB_W then
        self.x = self.x - (BB_W)
    end
    if self.y < 0 then
        self.y = self.y + (BB_H)
    end
    if self.y >= BB_H then
        self.y = self.y - (BB_H)
    end
end

---@param self Entity
---@param tint ALLEGRO_COLOR
function Entity.render_four(self, tint)
    local ox = 0 ---@type integer
    self:render_color_at(0, 0, tint)
    if self.x > BB_W / 2 then
        ox = -BB_W
        self:render_color_at(ox, 0, tint)
    else
        ox = BB_W
        self:render_color_at(ox, 0, tint)
    end
    if self.y > BB_H / 2 then
        self:render_color_at(0, -BB_H, tint)
        self:render_color_at(ox, -BB_H, tint)
    else
        self:render_color_at(0, BB_H, tint)
        self:render_color_at(ox, BB_H, tint)
    end
end

---@param self Entity
---@param x integer
---@param y integer
function Entity.render_at(self, x, y)
    error("To use c must override this in a sub-class.")
end

---@param self Entity
---@param x integer
---@param y integer
---@param c ALLEGRO_COLOR
function Entity.render_color_at(self, x, y, c)
    self:render_at(x, y)
end

---@param self Entity
---@param e Entity[]
---@return Entity?
function Entity.checkCollisions(self, e)
    for _, entity in ipairs(e) do
        if entity ~= self and entity:getDestructable() then
            local ex = entity:getX()
            local ey = entity:getY()
            local er = entity:getRadius()
            if checkCircleCollision(ex, ey, er, self.x, self.y, self.radius) then
                return entity
            end
        end
    end
end

---@param self Entity
---@return Player?
function Entity.getPlayerCollision(self)
    local rm = ResourceManager.getInstance()
    local player = rm:getData(RES_PLAYER) ---@type Player

    local ret = self:checkCollisions({ player }) --[[ @as Player? --]]
    return ret
end

---@param self Entity
---@return Entity?
function Entity.getEntityCollision(self)
    return self:checkCollisions(entities)
end

---@param self Entity
---@return Entity?
function Entity.getAllCollision(self)
    local e = self:getEntityCollision()
    if e then
        return e
    end
    return self:getPlayerCollision()
end

--- Returns true if dead
---@param self Entity
---@param damage integer
---@return boolean
function Entity.hit(self, damage)
    self.hp = self.hp - (damage)

    self.hilightCount = 500

    if self.hp <= 0 then
        self:explode()
        return true
    end

    return false
end

---@param self Entity
function Entity.explode(self)
    local big = false
    if self.radius >= 32 then
        big = true
    else
        big = false
    end
    local e = Explosion(self.x, self.y, big)
    new_entities[#new_entities + 1] = e
    if big then
        my_play_sample(RES_BIGEXPLOSION)
    else
        my_play_sample(RES_SMALLEXPLOSION)
    end
end

---@param self Entity
function Entity.spawn(self)
    if self.powerup >= 0 then
        local p = PowerUp(self.x, self.y, self.powerup)
        new_entities[#new_entities + 1] = p
    end
end

---@param self Entity
Entity.Entity = function(self)
    self.x = 0
    self.y = 0
    self.radius = 0
    self.dx = 0
    self.dy = 0

    self.isDestructable = true
    self.hp = 1
    self.powerup = -1
    self.hilightCount = 0
    self.points = 0
    self.ufo = false
end

return exports
