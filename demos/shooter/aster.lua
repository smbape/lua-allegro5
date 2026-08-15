local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/shooter/aster.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local a4_aux = require("demos.speed.a4_aux")
local data_m = require("data")
local demo = require("demo")
local expl = require("expl")
local game = require("game")

local new_table = common.new_table

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local ABS = a4_aux.ABS
local AL_RAND = a4_aux.AL_RAND
local draw_sprite = a4_aux.draw_sprite
local play_sample = a4_aux.play_sample
local retrace_count = a4_aux.retrace_count

local ASTA01 = data_m.ASTA01
local ASTB01 = data_m.ASTB01
local ASTC01 = data_m.ASTC01
local DEATH_SPL = data_m.DEATH_SPL
local data = data_m.data

local EXPLODE_FLAG = expl.EXPLODE_FLAG
local EXPLODE_FRAMES = expl.EXPLODE_FRAMES
local explosion = expl.explosion

local SPEED_SHIFT = game.SPEED_SHIFT

local PAN = game.PAN

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/shooter/aster.c
--]]

--[[ info about the asteroids (they used to be asteroids at least,
 - even if the current graphics look more like asteroids :-)
 --]]
local MAX_ASTEROIDS = 50

---@class ASTEROID
---@field x integer
---@field y integer
---@field d integer
---@field state integer
---@field shot boolean
---@overload fun(x? : integer, y? : integer, d? : integer, state? : integer, shot? : boolean): ASTEROID
local ASTEROID = common.class({
    __name = "ASTEROID",

    ---@param self ASTEROID
    ---@param x? integer
    ---@param y? integer
    ---@param d? integer
    ---@param state? integer
    ---@param shot? boolean
    __init__ = function(self, x, y, d, state, shot)
        if x == nil then x = 0 end
        if y == nil then y = 0 end
        if d == nil then d = 0 end
        if state == nil then state = 0 end
        if shot == nil then shot = false end
        self.x = x
        self.y = y
        self.d = d
        self.state = state
        self.shot = shot
    end
})

local asteroid = new_table(ASTEROID, MAX_ASTEROIDS)

local asteroid_count = 0



local function init_asteroids()
    for c = 1, MAX_ASTEROIDS do
        asteroid[c].x = 16 + AL_RAND() % (demo.SCREEN_W - 32)
        asteroid[c].y = -60 - (bit.band(AL_RAND(), 0x3f))
        asteroid[c].d = (function() if bit.band(AL_RAND(), 1) ~= 0 then return 1 else return -1 end end)()
        asteroid[c].state = -1
        asteroid[c].shot = false
    end
    asteroid_count = 2
end
exports.init_asteroids = init_asteroids



local function scroll_asteroids()
    for c = 1, asteroid_count do
        asteroid[c].y = asteroid[c].y + 1
    end
end
exports.scroll_asteroids = scroll_asteroids



local function add_asteroid()
    if asteroid_count < MAX_ASTEROIDS then
        asteroid_count = asteroid_count + 1 ---@type integer
    end
end
exports.add_asteroid = add_asteroid



local function move_asteroids()
    for c = 1, asteroid_count do
        if asteroid[c].shot then
            --[[ dying asteroid --]]
            if game.skip_count <= 0 then
                if asteroid[c].state < EXPLODE_FLAG + EXPLODE_FRAMES - 1 then
                    asteroid[c].state = asteroid[c].state + 1
                    if bit.band(asteroid[c].state, 1) ~= 0 then
                        asteroid[c].x = asteroid[c].x + (asteroid[c].d)
                    end
                else
                    asteroid[c].x = 16 + AL_RAND() % (demo.SCREEN_W - 32)
                    asteroid[c].y = -60 - (bit.band(AL_RAND(), 0x3f))
                    asteroid[c].d = (function() if bit.band(AL_RAND(), 1) ~= 0 then return 1 else return -1 end end)()
                    asteroid[c].shot = false
                    asteroid[c].state = -1
                end
            end
        else
            --[[ move asteroid sideways --]]
            asteroid[c].x = asteroid[c].x + (asteroid[c].d)
            if asteroid[c].x < -60 then
                asteroid[c].x = demo.SCREEN_W
            elseif asteroid[c].x > demo.SCREEN_W + 60 then
                asteroid[c].x = -60
            end
        end

        --[[ move asteroid vertically --]]
        asteroid[c].y = asteroid[c].y + (1)

        if asteroid[c].y > demo.SCREEN_H + 30 then
            if not asteroid[c].shot then
                asteroid[c].x = AL_RAND() % (demo.SCREEN_W - 32)
                asteroid[c].y = -32 - (bit.band(AL_RAND(), 0x3f))
                asteroid[c].d = (function() if bit.band(AL_RAND(), 1) ~= 0 then return 1 else return -1 end end)()
            end
        else
            --[[ asteroid collided with player? --]]
            if (ABS(asteroid[c].x - (bit.rshift(game.player_x_pos, SPEED_SHIFT))) < 48)
                and (ABS(asteroid[c].y - (demo.SCREEN_H - 42)) < 32) then
                if (not game.player_hit) and (not asteroid[c].shot) then
                    if not demo.cheat then
                        game.ship_state = EXPLODE_FLAG
                        game.player_hit = true
                    end
                    if (not demo.cheat) or (not asteroid[c].shot) then
                        play_sample(data[DEATH_SPL + INDEX_BASE].dat, 255,
                            PAN(bit.rshift(game.player_x_pos, SPEED_SHIFT)), 1000, false)
                    end
                end
                if not asteroid[c].shot then
                    asteroid[c].shot = true
                    asteroid[c].state = EXPLODE_FLAG
                end
            end
        end
    end
end
exports.move_asteroids = move_asteroids



---@param x integer
---@param y integer
---@param s integer
---@return boolean
local function asteroid_collision(x, y, s)
    for i = 1, asteroid_count do
        if (ABS(y - asteroid[i].y) < s)
            and (ABS(x - asteroid[i].x) < s)
            and (not asteroid[i].shot) then
            asteroid[i].shot = true
            asteroid[i].state = EXPLODE_FLAG
            return true
        end
    end
    return false
end
exports.asteroid_collision = asteroid_collision



local function draw_asteroids()
    local i, j ---@type integer, integer
    local spr ---@type ALLEGRO_BITMAP

    for c = 0, asteroid_count - INDEX_BASE do
        local x = asteroid[c + INDEX_BASE].x ---@type integer
        local y = asteroid[c + INDEX_BASE].y ---@type integer

        if asteroid[c + INDEX_BASE].state >= EXPLODE_FLAG then
            spr = explosion[asteroid[c + INDEX_BASE].state - EXPLODE_FLAG + INDEX_BASE]
        else
            if c % 3 == 0 then
                i = ASTA01
            elseif c % 3 == 1 then
                i = ASTB01
            elseif c % 3 == 2 then
                i = ASTC01
            else
                i = 0
            end
            j = (math.floor(retrace_count() / (6 - bit.band(c, 3))) + c) % 15
            if bit.band(c, 1) ~= 0 then
                spr = data[i + 14 - j + INDEX_BASE].dat
            else
                spr = data[i + j + INDEX_BASE].dat
            end
        end

        local sprw = allegro5.al_get_bitmap_width(spr)
        local sprh = allegro5.al_get_bitmap_height(spr)
        draw_sprite(spr, x - math.floor(sprw / 2), y - math.floor(sprh / 2))
    end
end
exports.draw_asteroids = draw_asteroids

return exports
