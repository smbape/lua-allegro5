local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/Explosion.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local Entity = require("Entity").Entity
local Resource = require("Resource")
local ResourceManager = require("ResourceManager").ResourceManager

local RES_LARGEEXPLOSION0 = Resource.RES_LARGEEXPLOSION0
local RES_SMALLEXPLOSION0 = Resource.RES_SMALLEXPLOSION0

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local NUM_FRAMES = 5 ---@type integer
local FRAME_TIME = 100 ---@type integer

---@class Explosion : Entity
---@field private frameCount integer
---@field private currFrame integer
---@field private big boolean
---@overload fun(x : number, y : number, big : boolean): Explosion
local Explosion = common.class({
    __name = "Explosion",
}, Entity)
exports.Explosion = Explosion

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/Explosion.cpp
--]]

---@param self Explosion
---@param step integer
---@return boolean
function Explosion.logic(self, step)
    self.frameCount = self.frameCount - (step)
    if self.frameCount <= 0 then
        self.currFrame = self.currFrame + 1
        self.frameCount = FRAME_TIME
        if self.currFrame >= NUM_FRAMES then
            return false
        end
    end

    return true
end

---@param self Explosion
---@param offx integer
---@param offy integer
function Explosion.render_at(self, offx, offy)
    local rm = ResourceManager.getInstance()
    local bitmapIndex = 0 ---@type integer

    if self.big then
        bitmapIndex = RES_LARGEEXPLOSION0 + self.currFrame
    else
        bitmapIndex = RES_SMALLEXPLOSION0 + self.currFrame
    end

    local bitmap = rm:getData(bitmapIndex) ---@type ALLEGRO_BITMAP?

    allegro5.al_draw_rotated_bitmap(bitmap, self.radius, self.radius, offx + self.x, offy + self.y, 0, 0)
end

---@param self Explosion
---@param x number
---@param y number
---@param big boolean
function Explosion.Explosion(self, x, y, big)
    Entity.Entity(self)

    self.x = x
    self.y = y
    self.dx = 0.0
    self.dy = 0.0
    self.radius = (function() if (big) then return 32 else return 12 end end)()
    self.isDestructable = false
    self.hp = 1

    self.frameCount = FRAME_TIME
    self.currFrame = 0
    self.big = big
end

return exports
