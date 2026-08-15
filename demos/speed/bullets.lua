local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/speed/bullets.c
--]]

local allegro5_lua = require("allegro5_lua")
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local a4_aux = require("a4_aux")
local sound = require("sound")
local speed = require("speed")
local view = require("view")

local new_table = common.new_table

local INDEX_BASE = 1 -- lua is 1-based indexed

local cos = math.cos
local sin = math.sin

local makecol = a4_aux.makecol
local line = a4_aux.line
local polygon = a4_aux.polygon

local sfx_shoot = sound.sfx_shoot

local view_size = view.view_size

--[[
 -    SPEED - by Shawn Hargreaves, 1999
 -
 -    Bullet animation and display routines.
 --]]


--[[ bullet info --]]
---@class BULLET
---@field x number
---@field y number
---@field next? BULLET
---@overload fun(x? : number, y? : number, next? : BULLET): BULLET
local BULLET = common.class({
    __name = "BULLET",

    ---@param self BULLET
    ---@param x? number
    ---@param y? number
    ---@param next? BULLET
    __init__ = function(self, x, y, next)
        if x == nil then x = 0 end
        if y == nil then y = 0 end
        self.x = x
        self.y = y
        self.next = next
    end
})


local bullets ---@type BULLET?



--[[ interface for the aliens to query bullet positions --]]
---@return BULLET?
---@return number
---@return number
local function get_first_bullet()
    if not bullets then
        return nil, 0, 0
    end
    return bullets, bullets.x, bullets.y
end
exports.get_first_bullet = get_first_bullet



--[[ interface for the aliens to query bullet positions --]]
---@param b BULLET
---@return BULLET?
---@return number
---@return number
local function get_next_bullet(b)
    local bul = b.next

    if not bul then
        return nil, 0, 0
    end

    return bul, bul.x, bul.y
end
exports.get_next_bullet = get_next_bullet



--[[ interface for the aliens to get rid of bullets when they explode --]]
---@param b BULLET
local function kill_bullet(b)
    b.y = -65536
end
exports.kill_bullet = kill_bullet



--[[ initialises the bullets functions --]]
local function init_bullets()
    bullets = nil
end
exports.init_bullets = init_bullets



--[[ closes down the bullets module --]]
local function shutdown_bullets()
    local b ---@type BULLET

    while bullets do
        b = bullets
        bullets = bullets.next
        -- free(b)
        b.next = nil
    end
end
exports.shutdown_bullets = shutdown_bullets



--[[ fires a new bullet --]]
---@param x number
local function fire_bullet(x)
    local b = BULLET()

    b.x = x
    b.y = 0.96

    b.next = bullets
    bullets = b

    sfx_shoot()
end
exports.fire_bullet = fire_bullet


---@param value BULLET
local function bullets_setter(value)
    bullets = value
end

---@param self BULLET
---@return fun(value : BULLET)
local function next_setter(self)
    ---@param value BULLET
    return function(value)
        self.next = value
    end
end


--[[ updates the bullets position --]]
local function update_bullets()
    local p = bullets_setter ---@type fun(value : BULLET)
    local b = bullets
    local tmp ---@type BULLET

    while b do
        b.y = b.y - (0.025)

        if b.y < 0 then
            p(b.next)
            tmp = b
            b = b.next
            -- free(tmp)
            tmp.next = nil
        else
            p = next_setter(b)
            b = b.next
        end
    end
end
exports.update_bullets = update_bullets



--[[ draws the bullets --]]
---@param r integer
---@param g integer
---@param b integer
---@param project fun(f : number[], i : integer[], c : integer) : boolean
local function draw_bullets(r, g, b, project)
    local bul = bullets ---@type BULLET?
    local c1 = makecol(128 + math.floor(r / 2), 128 + math.floor(g / 2), 128 + math.floor(b / 2))
    local c2 = (function() if g ~= 0 then return makecol(math.floor(r / 5), math.floor(g / 5), math.floor(b / 5)) else return
            makecol(math.floor(r / 4), math.floor(g / 4), math.floor(b / 4)) end end)()
    local shape = new_table(0, 6) ---@type number[]
    local ishape = new_table(0, 6) ---@type integer[]

    while bul do
        if bul.y > 0 then
            shape[0 + INDEX_BASE] = bul.x - 0.005
            shape[1 + INDEX_BASE] = bul.y + 0.01

            shape[2 + INDEX_BASE] = bul.x + 0.005
            shape[3 + INDEX_BASE] = bul.y + 0.01

            shape[4 + INDEX_BASE] = bul.x
            shape[5 + INDEX_BASE] = bul.y - 0.015

            if project(shape, ishape, 6) then
                polygon(3, ishape, c1)

                if not speed.low_detail then
                    local cx = (ishape[0 + INDEX_BASE] + ishape[2 + INDEX_BASE] + ishape[4 + INDEX_BASE]) / 3
                    local cy = (ishape[1 + INDEX_BASE] + ishape[3 + INDEX_BASE] + ishape[5 + INDEX_BASE]) / 3

                    local boxx = { -1, -1, 1, 1 } ---@type [number, number, number, number]
                    local boxy = { -1, 1, 1, -1 } ---@type [number, number, number, number]

                    for i = 0, 4 - INDEX_BASE do
                        local rot = (function() if bit.band(math.floor(bul.x * 256), 1) ~= 0 then return bul.y else return -
                                bul.y end end)()

                        local tx = cos(rot) * boxx[i + INDEX_BASE] + sin(rot) * boxy[i + INDEX_BASE]
                        local ty = sin(rot) * boxx[i + INDEX_BASE] - cos(rot) * boxy[i + INDEX_BASE]

                        boxx[i + INDEX_BASE] = tx * bul.y * view_size() / 8
                        boxy[i + INDEX_BASE] = ty * bul.y * view_size() / 8
                    end

                    line(math.floor(cx + boxx[0 + INDEX_BASE]), math.floor(cy + boxy[0 + INDEX_BASE]),
                        math.floor(cx + boxx[1 + INDEX_BASE]), math.floor(cy + boxy[1 + INDEX_BASE]), c2)
                    line(math.floor(cx + boxx[1 + INDEX_BASE]), math.floor(cy + boxy[1 + INDEX_BASE]),
                        math.floor(cx + boxx[2 + INDEX_BASE]), math.floor(cy + boxy[2 + INDEX_BASE]), c2)
                    line(math.floor(cx + boxx[2 + INDEX_BASE]), math.floor(cy + boxy[2 + INDEX_BASE]),
                        math.floor(cx + boxx[3 + INDEX_BASE]), math.floor(cy + boxy[3 + INDEX_BASE]), c2)
                    line(math.floor(cx + boxx[3 + INDEX_BASE]), math.floor(cy + boxy[3 + INDEX_BASE]),
                        math.floor(cx + boxx[0 + INDEX_BASE]), math.floor(cy + boxy[0 + INDEX_BASE]), c2)
                end
            end
        end

        bul = bul.next ---@type BULLET?
    end
end
exports.draw_bullets = draw_bullets

return exports
