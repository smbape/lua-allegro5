local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/Wave.hpp
--]]

local common = require("examples.common")
local cosmic_protector = require("cosmic_protector")
local logic = require("logic")
local render = require("render")
local Game = require("Game")
local LargeAsteroid = require("LargeAsteroid").LargeAsteroid

local rand = common.rand

local entities = logic.entities

local showWave = render.showWave

local randf = Game.randf

local INDEX_BASE = 1 -- lua is 1-based indexed

---@class Wave
---@field private rippleNum integer
---@overload fun(): Wave
local Wave = common.class({
    __name = "Wave",
})
exports.Wave = Wave

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/wave.cpp
--]]

---@param self Wave
function Wave.Wave(self)
    self.rippleNum = 0
end

---@param self Wave
---@return boolean
function Wave.next(self)
    self.rippleNum = self.rippleNum + 1

    showWave(self.rippleNum)

    for i = 0, self.rippleNum + 1 - INDEX_BASE do
        local x, y = 0, 0 ---@type number, number
        if rand() % 2 ~= 0 then
            x = -randf(32.0, 100.0)
        else
            x = cosmic_protector.BB_W + randf(32.0, 100.0)
        end
        if rand() % 2 ~= 0 then
            y = -randf(32.0, 70.0)
        else
            y = cosmic_protector.BB_H + randf(32.0, 70.0)
        end
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
        local la = LargeAsteroid(x, y, dx, dy, da)
        if (rand() % 3) == 0 then
            la:setPowerUp(rand() % 2)
        end
        entities[#entities + 1] = la
    end

    return true
end

return exports
