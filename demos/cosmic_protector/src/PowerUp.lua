local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/PowerUp.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local cosmic_protector = require("cosmic_protector")
local sound = require("sound")
local Entity = require("Entity").Entity
local Game = require("Game")
local Resource = require("Resource")
local ResourceManager = require("ResourceManager").ResourceManager

local rand = common.rand

local my_play_sample = sound.my_play_sample

local randf = Game.randf

local RES_LIFEPOWERUP = Resource.RES_LIFEPOWERUP
local RES_POWERUP = Resource.RES_POWERUP
local RES_WEAPONPOWERUP = Resource.RES_WEAPONPOWERUP

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local POWERUP_LIFE = 0; exports.POWERUP_LIFE = POWERUP_LIFE
local POWERUP_WEAPON = 1; exports.POWERUP_WEAPON = POWERUP_WEAPON

---@class PowerUp : Entity
---@field private type integer
---@field private bitmap? ALLEGRO_BITMAP
---@field private angle number
---@field private da number
---@overload fun(x : number, y : number, type : integer): PowerUp
local PowerUp = common.class({
    __name = "PowerUp",
}, Entity)
exports.PowerUp = PowerUp

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/PowerUp.cpp
--]]

---@param self PowerUp
---@param step integer
---@return boolean
function PowerUp.logic(self, step)
    self.angle = self.angle + (self.da * step)

    self.x = self.x + (self.dx)
    self.y = self.y + (self.dy)

    if self.x < -self.radius or self.x > cosmic_protector.BB_W + self.radius or self.y < -self.radius or self.y > cosmic_protector.BB_H + self.radius then
        return false
    end

    local p = self:getPlayerCollision()
    if p then
        p:givePowerUp(self.type)
        my_play_sample(RES_POWERUP)
        return false
    end

    if not Entity.logic(self, step) then
        return false
    end

    return true
end

---@param self PowerUp
---@param offx integer
---@param offy integer
function PowerUp.render_at(self, offx, offy)
    allegro5.al_draw_rotated_bitmap(self.bitmap, self.radius, self.radius, offx + self.x, offy + self.y, self.angle, 0)
end

---@param self PowerUp
---@param x number
---@param y number
---@param _type integer
function PowerUp.PowerUp(self, x, y, _type)
    local SPIN_SPEED = 0.002

    Entity.Entity(self)

    self.angle = 0

    self.x = x
    self.y = y
    self.type = _type

    self.dx = randf(0.5, 1.2)
    self.dy = randf(0.5, 1.2)
    self.radius = 16
    self.isDestructable = false
    self.hp = 1

    self.da = (function() if (rand() % 2) then return -SPIN_SPEED else return SPIN_SPEED end end)()

    local rm = ResourceManager.getInstance()


    if _type == POWERUP_LIFE then
        self.bitmap = rm:getData(RES_LIFEPOWERUP) ---@type ALLEGRO_BITMAP
    else
        _type = POWERUP_WEAPON
        self.bitmap = rm:getData(RES_WEAPONPOWERUP) ---@type ALLEGRO_BITMAP
    end
end

return exports
