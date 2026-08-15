---@class bullet
---@field bullet_list? BULLET
local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/shooter/bullet.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local a4_aux = require("demos.speed.a4_aux")
local aster ---@module "aster"
local data_m = require("data")
local game ---@module "game"

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local draw_sprite = a4_aux.draw_sprite
local play_sample = a4_aux.play_sample

local asteroid_collision ---@type fun(x: integer, y: integer, s: integer) : integer

local BOOM_SPL = data_m.BOOM_SPL
local ROCKET = data_m.ROCKET
local data = data_m.data

local PAN ---@type fun(x: integer) : integer

---@class BULLET
---@field x integer
---@field y integer
---@field next? BULLET
---@overload fun(x? : integer, y? : integer, next? : BULLET): BULLET
local BULLET = common.class({
    __name = "BULLET",

    ---@param self BULLET
    ---@param x? integer
    ---@param y? integer
    ---@param next? BULLET
    __init__ = function(self, x, y, next)
        if x == nil then x = 0 end
        if y == nil then y = 0 end
        self.x = x
        self.y = y
        self.next = next
    end
})

local bullet_list ---@type BULLET?

function exports.init()
    aster = require("aster")
    game = require("game")

    asteroid_collision = aster.asteroid_collision

    PAN = game.PAN
end

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/shooter/bullet.c
--]]

--[[ position of the bullets --]]
local BULLET_SPEED = 6 ---@type integer

bullet_list = nil

--[[ add a bullet to the list --]]
---@param x integer
---@param y integer
---@return BULLET
local function add_bullet(x, y)
    local bullet = BULLET()
    bullet.x = x
    bullet.y = y
    bullet.next = nil

    --[[ special treatment for head --]]
    if not bullet_list then
        bullet_list = bullet
    else
        local iter = bullet_list ---@type BULLET
        while iter and iter.next do
            iter = iter.next
        end
        if iter then
            iter.next = bullet
        end
    end

    return bullet
end
exports.add_bullet = add_bullet



--[[ delete a bullet and return the next in the list --]]
---@param bullet BULLET
---@return BULLET?
local function delete_bullet(bullet)
    if not bullet_list then
        return
    end

    --[[ special treatment for head --]]
    if bullet == bullet_list then
        bullet_list = bullet.next
        -- free(bullet)
        return bullet_list
    else
        local iter = bullet_list ---@type BULLET
        while iter and iter.next ~= bullet do
            iter = iter.next
        end

        if iter then
            iter.next = bullet.next
        end

        -- free(bullet)

        if iter then
            return iter.next
        end
    end
end
exports.delete_bullet = delete_bullet



local function move_bullets()
    local bullet = bullet_list
    while bullet do
        bullet.y = bullet.y - (BULLET_SPEED) ---@type integer

        --[[ if the bullet is at the top of the screen, delete it --]]
        if bullet.y < 8 then
            bullet = delete_bullet(bullet)
        --[[ shot an asteroid? --]]
        elseif asteroid_collision(bullet.x, bullet.y, 20) then
            game.score = game.score + (10)
            play_sample(data[BOOM_SPL + INDEX_BASE].dat, 255, PAN(bullet.x), 1000, false)
            --[[ delete the bullet that killed the alien --]]
            bullet = delete_bullet(bullet)
        else
            bullet = bullet.next
        end
    end
end
exports.move_bullets = move_bullets



local function draw_bullets()
    local bullet = bullet_list ---@type BULLET?
    while bullet do
        local x = bullet.x
        local y = bullet.y

        local spr = data[ROCKET + INDEX_BASE].dat --[[@as ALLEGRO_BITMAP --]]
        local sprw = allegro5.al_get_bitmap_width(spr)
        local sprh = allegro5.al_get_bitmap_height(spr)
        draw_sprite(spr, x - math.floor(sprw / 2), y - math.floor(sprh / 2))
        bullet = bullet.next
    end
end
exports.draw_bullets = draw_bullets

local getters = {
    bullet_list = function() return bullet_list end,
}

local setters = {
    bullet_list = function(value) bullet_list = value end,
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
