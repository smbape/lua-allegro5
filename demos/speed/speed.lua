---@class speed
---@field cheat boolean
---@field low_detail boolean
---@field no_grid boolean
---@field no_music boolean
---@field lives integer
---@field score integer
local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/speed/speed.h
--]]

--[[
 -    SPEED - by Shawn Hargreaves, 1999
 -
 -    Global defines.
 --]]

--[[ global state variables --]]
local cheat = false ---@type boolean
local low_detail = false ---@type boolean
local no_grid = false ---@type boolean
local no_music = false ---@type boolean
local lives = 0 ---@type integer
local score = 0 ---@type integer

local getters = {
    cheat = function() return cheat end,
    low_detail = function() return low_detail end,
    no_grid = function() return no_grid end,
    no_music = function() return no_music end,
    lives = function() return lives end,
    score = function() return score end,
}

local setters = {
    cheat = function(value) cheat = value end,
    low_detail = function(value) low_detail = value end,
    no_grid = function(value) no_grid = value end,
    no_music = function(value) no_music = value end,
    lives = function(value) lives = value end,
    score = function(value) score = value end,
}

setmetatable(exports, {
    __index = function(self, key)
        local getter = getters[key]
        if type(getter) == "function" then
            return getter()
        end
        return nil
    end,
    __newindex = function(self, key, value)
        local setter = setters[key]
        if type(setter) == "function" then
            setter(value)
        else
            rawset(self, key, value)
        end
    end
})

return exports
