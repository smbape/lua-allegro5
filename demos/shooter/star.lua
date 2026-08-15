local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/shooter/star.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local a4_aux = require("demos.speed.a4_aux")
local demo = require("demo")

local new_table = common.new_table

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local AL_RAND = a4_aux.AL_RAND
local CLAMP = a4_aux.CLAMP
local fixcos = a4_aux.fixcos
local fixdiv = a4_aux.fixdiv
local fixmul = a4_aux.fixmul
local fixsin = a4_aux.fixsin
local itofix = a4_aux.itofix

local get_palette = demo.get_palette

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/shooter/star.c
--]]

--[[ for the starfield --]]
local MAX_STARS = 512

---@class STAR
---@field x integer
---@field y integer
---@field z integer
---@field ox integer
---@field oy integer
---@overload fun(x? : integer, y? : integer, z? : integer, ox? : integer, oy? : integer): STAR
local STAR = common.class({
    __name = "STAR",

    ---@param self STAR
    ---@param x? integer
    ---@param y? integer
    ---@param z? integer
    ---@param ox? integer
    ---@param oy? integer
    __init__ = function(self, x, y, z, ox, oy)
        if x == nil then x = 0 end
        if y == nil then y = 0 end
        if z == nil then z = 0 end
        if ox == nil then ox = 0 end
        if oy == nil then oy = 0 end
        self.x = x
        self.y = y
        self.z = z
        self.ox = ox
        self.oy = oy
    end
})

local star = new_table(STAR, MAX_STARS)

local star_count = 0
local star_count_count = 0



local function init_starfield_2d()
    for c = 1, MAX_STARS do
        star[c].ox = AL_RAND() % demo.SCREEN_W
        star[c].oy = AL_RAND() % demo.SCREEN_H
        star[c].z = bit.band(AL_RAND(), 7)
    end
end
exports.init_starfield_2d = init_starfield_2d



local function starfield_2d()
    for c = 1, MAX_STARS do
        star[c].oy = star[c].oy + (bit.arshift(star[c].z, 1) + 1)
        if star[c].oy >= demo.SCREEN_H then
            star[c].oy = 0
        end
    end
end
exports.starfield_2d = starfield_2d



local function scroll_stars()
    for c = 1, MAX_STARS do
        star[c].oy = star[c].oy + 1
        if star[c].oy >= demo.SCREEN_H then
            star[c].oy = 0
        end
    end
end
exports.scroll_stars = scroll_stars



local function draw_starfield_2d()
    for c = 1, MAX_STARS do
        local y = star[c].oy ---@type integer
        ---@type integer
        local x = math.floor((star[c].ox - math.floor(demo.SCREEN_W / 2)) *
                (math.floor(y / (4 - math.floor(star[c].z / 2))) +
                    demo.SCREEN_H) / demo.SCREEN_H) +
            math.floor(demo.SCREEN_W / 2)

        allegro5.al_draw_filled_circle(x, y, 1, get_palette(15 - star[c].z))
    end
end
exports.draw_starfield_2d = draw_starfield_2d



local function init_starfield_3d()
    for c = 1, MAX_STARS do
        star[c].z = 0
        star[c].ox = -1
        star[c].oy = -1
    end
end
exports.init_starfield_3d = init_starfield_3d

local function starfield_3d()
    for c = 1, star_count do
        if star[c].z <= itofix(1) then
            local x = itofix(bit.band(AL_RAND(), 0xff)) ---@type integer
            local y = itofix((bit.band(AL_RAND(), 3) + 1) * demo.SCREEN_W) ---@type integer

            star[c].x = fixmul(fixcos(x), y)
            star[c].y = fixmul(fixsin(x), y)
            star[c].z = itofix((bit.band(AL_RAND(), 0x1f)) + 0x20)
        end

        local x = fixdiv(star[c].x, star[c].z) ---@type integer
        local y = fixdiv(star[c].y, star[c].z) ---@type integer

        local ix = bit.arshift(x, 16) + math.floor(demo.SCREEN_W / 2) ---@type integer
        local iy = bit.arshift(y, 16) + math.floor(demo.SCREEN_H / 2) ---@type integer

        if (ix >= 0) and (ix < demo.SCREEN_W) and (iy >= 0)
            and (iy < demo.SCREEN_H) then
            star[c].ox = ix
            star[c].oy = iy
            star[c].z = star[c].z - (4096)
        else
            star[c].ox = -1
            star[c].oy = -1
            star[c].z = 0
        end
    end

    --[[ wake up new star --]]
    if star_count < MAX_STARS then
        star_count_count = star_count_count + 1 ---@type integer
        if star_count_count >= 8 then
            star_count_count = 0
            star_count = star_count + 1 ---@type integer
        end
    end
end
exports.starfield_3d = starfield_3d



local function draw_starfield_3d()
    for c = 1, star_count do
        local c2 = 7 - bit.arshift(star[c].z, 18) ---@type integer
        allegro5.al_draw_filled_circle(star[c].ox, star[c].oy, 3, get_palette(CLAMP(0, c2, 7)))
    end
end
exports.draw_starfield_3d = draw_starfield_3d

return exports
