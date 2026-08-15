local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/MediumAsteroid.hpp
--]]

local common = require("examples.common")
local logic = require("logic")
local Asteroid = require("Asteroid").Asteroid
local Entity = require("Entity").Entity
local Game = require("Game")
local Resource = require("Resource")
local SmallAsteroid = require("SmallAsteroid").SmallAsteroid

local rand = common.rand

local new_entities = logic.new_entities

local randf = Game.randf

local RES_MEDIUMASTEROID = Resource.RES_MEDIUMASTEROID

---@class MediumAsteroid : Asteroid
---@overload fun(): MediumAsteroid
local MediumAsteroid = common.class({
    __name = "MediumAsteroid",
}, Asteroid)
exports.MediumAsteroid = MediumAsteroid

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/MediumAsteroid.cpp
--]]

---@param self MediumAsteroid
function MediumAsteroid.spawn(self)
    -- Break into small fragments
    for _ = 1, 3 do
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
        local sa = SmallAsteroid()
        sa:init(self.x, self.y, dx, dy, da)
        new_entities[#new_entities + 1] = sa
    end

    Entity.spawn(self)
end

---@param self MediumAsteroid
function MediumAsteroid.MediumAsteroid(self)
    Asteroid.Asteroid(self, 20, RES_MEDIUMASTEROID)
    self.hp = 4
    self.points = 50
end

---@param self MediumAsteroid
function MediumAsteroid.__destroy(self)
end

return exports
