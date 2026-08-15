local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/LargeAsteroid.hpp
--]]

local common = require("examples.common")
local logic = require("logic")
local Asteroid = require("Asteroid").Asteroid
local Entity = require("Entity").Entity
local Game = require("Game")
local MediumAsteroid = require("MediumAsteroid").MediumAsteroid
local Resource = require("Resource")

local rand = common.rand

local new_entities = logic.new_entities

local randf = Game.randf

local RES_LARGEASTEROID = Resource.RES_LARGEASTEROID

---@class LargeAsteroid : Asteroid
---@overload fun(x? : number, y? : number, speed_x? : number, speed_y? : number, da? : number): LargeAsteroid
local LargeAsteroid = common.class({
    __name = "LargeAsteroid",
}, Asteroid)
exports.LargeAsteroid = LargeAsteroid

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/LargeAsteroid.cpp
--]]

---@param self LargeAsteroid
function LargeAsteroid.spawn(self)
    -- Break into small fragments
    for _ = 1, 2 do
        local dx = randf(0.06, 0.12)
        local dy = randf(0.04, 0.08)
        local da = randf(0.001, 0.005)
        if rand() % 2 ~= 0 then
            dx = -dx ---@type number
        end
        if rand() % 2 ~= 0 then
            dy = -dy ---@type number
        end
        if rand() % 2 ~= 0 then
            da = -da ---@type number
        end
        local ma = MediumAsteroid()
        ma:init(self.x, self.y, dx, dy, da)
        new_entities[#new_entities + 1] = ma
    end

    Entity.spawn(self)
end

---@param self LargeAsteroid
---@param x? number
---@param y? number
---@param speed_x? number
---@param speed_y? number
---@param da? number
function LargeAsteroid.LargeAsteroid(self, x, y, speed_x, speed_y, da)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    if speed_x == nil then speed_x = 0 end
    if speed_y == nil then speed_y = 0 end
    if da == nil then da = 0 end

    Asteroid.Asteroid(self, 32, RES_LARGEASTEROID)
    self:init(x, y, speed_x, speed_y, da)
    self.hp = 6
    self.points = 100
end

function LargeAsteroid.__destroy(self)
end

return exports
