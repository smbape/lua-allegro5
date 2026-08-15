local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/SmallAsteroid.hpp
--]]

local common = require("examples.common")
local Asteroid = require("Asteroid").Asteroid
local Resource = require("Resource")

local RES_SMALLASTEROID = Resource.RES_SMALLASTEROID

---@class SmallAsteroid : Asteroid
---@overload fun(): SmallAsteroid
local SmallAsteroid = common.class({
    __name = "SmallAsteroid",
}, Asteroid)
exports.SmallAsteroid = SmallAsteroid

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/SmallAsteroid.cpp
--]]

---@param self SmallAsteroid
function SmallAsteroid.SmallAsteroid(self)
    Asteroid.Asteroid(self, 10, RES_SMALLASTEROID)
    self.points = 10
end

---@param self SmallAsteroid
function SmallAsteroid.__destroy(self)
end

return exports
