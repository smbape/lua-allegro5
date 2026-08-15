local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/speed/explode.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local a4_aux = require("a4_aux")
local speed = require("speed")
local view = require("view")

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local MAX = a4_aux.MAX

local makecol = a4_aux.makecol
local circle = a4_aux.circle
local circlefill = a4_aux.circlefill

local view_size = view.view_size

--[[
 -    SPEED - by Shawn Hargreaves, 1999
 -
 -    Explosion graphics effect.
 --]]



--[[ explosion info --]]
---@class EXPLOSION
---@field x number
---@field y number
---@field big integer
---@field time number
---@field next? EXPLOSION
---@overload fun(x? : number, y? : number, big? : integer, time? : number, next? : EXPLOSION): EXPLOSION
local EXPLOSION = common.class({
    __name = "EXPLOSION",

    ---@param self EXPLOSION
    ---@param x? number
    ---@param y? number
    ---@param big? integer
    ---@param time? number
    ---@param next? EXPLOSION
    __init__ = function(self, x, y, big, time, next)
        if x == nil then x = 0 end
        if y == nil then y = 0 end
        if big == nil then big = 0 end
        if time == nil then time = 0 end
        self.x = x
        self.y = y
        self.big = big
        self.time = time
        self.next = next
    end
})


local explosions ---@type EXPLOSION?



--[[ initialises the explode functions --]]
local function init_explode()
    explosions = nil
end
exports.init_explode = init_explode



--[[ closes down the explode module --]]
local function shutdown_explode()
    local e ---@type EXPLOSION

    while explosions do
        e = explosions
        explosions = explosions.next ---@type EXPLOSION?
        -- free(e)
        e.next = nil
    end
end
exports.shutdown_explode = shutdown_explode



--[[ triggers a new explosion --]]
---@param x number
---@param y number
---@param big integer
local function explode(x, y, big)
    local e = EXPLOSION()

    e.x = x
    e.y = y

    e.big = big

    e.time = 0

    e.next = explosions
    explosions = e
end
exports.explode = explode



---@param value EXPLOSION
local function explosions_setter(value)
    explosions = value
end

---@param self EXPLOSION
---@return fun(value : EXPLOSION)
local function next_setter(self)
    ---@param value EXPLOSION
    return function(value)
        self.next = value
    end
end

--[[ updates the explode position --]]
local function update_explode()
    local p = explosions_setter ---@type fun(value : EXPLOSION)
    local e = explosions ---@type EXPLOSION?
    local tmp ---@type EXPLOSION?

    while e do
        e.time = e.time + (1.0 / (e.big / 2.0 + 1))

        if e.time > 32 then
            p(e.next)
            tmp = e
            e = e.next
            -- free(tmp)
            tmp.next = nil
        else
            p = next_setter(e)
            e = e.next
        end
    end
end
exports.update_explode = update_explode



--[[ draws explosions --]]
---@param r integer
---@param g integer
---@param b integer
---@param project fun(f : number[], i : integer[], c : integer) : boolean
local function draw_explode(r, g, b, project)
    local e = explosions
    local size = view_size()
    local pos = { 0, 0 } --@type [number, number]
    local ipos = { 0, 0 } --@type [integer, integer]
    local rr, gg, bb, c, s = 0, 0, 0, 0, 0 ---@type integer, integer, integer, integer, integer
    local col = allegro5.ALLEGRO_COLOR()

    while e do
        pos[0 + INDEX_BASE] = e.x
        pos[1 + INDEX_BASE] = e.y

        if project(pos, ipos, 2) then
            s = math.floor(e.time * size / math.floor(512 / (e.big + 1)))

            if (not speed.low_detail) and (e.time < 24) then
                c = math.floor((24 - e.time) * 255 / 24)
                col = makecol(c, c, c)

                circle(ipos[0 + INDEX_BASE], ipos[1 + INDEX_BASE], s * 2, col)
                circle(ipos[0 + INDEX_BASE], ipos[1 + INDEX_BASE], math.floor(s * s / 8), col)
            end

            if e.time < 32 then
                rr = math.floor((32 - e.time) * r / 32)
                gg = math.floor((32 - e.time) * g / 32)
                bb = math.floor((32 - e.time) * b / 32)

                c = MAX(math.floor((24 - e.time) * 255 / 24), 0)

                rr = MAX(rr, c)
                gg = MAX(gg, c)
                bb = MAX(bb, c)

                col = makecol(rr, gg, bb)

                circlefill(ipos[0 + INDEX_BASE], ipos[1 + INDEX_BASE], s, col)
            end
        end

        e = e.next
    end
end
exports.draw_explode = draw_explode

return exports
