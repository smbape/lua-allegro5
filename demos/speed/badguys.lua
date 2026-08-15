local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/speed/badguys.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local a4_aux = require("a4_aux")
local common = require("examples.common")
local bullets = require("bullets")
local explode_m = require("explode")
local message_m = require("message")
local player = require("player")
local sound = require("sound")
local speed = require("speed")

local new_table = common.new_table
local rand = common.rand

local INDEX_BASE = 1 -- lua is 1-based indexed

local sin = math.sin

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local ABS = a4_aux.ABS
local SGN = a4_aux.SGN

local key = a4_aux.key
local makecol = a4_aux.makecol
local poll_input_wait = a4_aux.poll_input_wait
local polygon = a4_aux.polygon

local get_first_bullet = bullets.get_first_bullet
local get_next_bullet = bullets.get_next_bullet
local kill_bullet = bullets.kill_bullet

local explode = explode_m.explode

local message = message_m.message

local find_target = player.find_target
local kill_player = player.kill_player
local player_dying = player.player_dying
local player_pos = player.player_pos

local sfx_explode_alien = sound.sfx_explode_alien
local sfx_ping = sound.sfx_ping

--[[
 -    SPEED - by Shawn Hargreaves, 1999
 -
 -    Enemy control routines (attack waves).
 --]]


--[[ description of an attack wave --]]
---@class WAVEINFO
---@field count integer how many to create
---@field delay number how long to delay them
---@field delay_rand number random delay factor
---@field speed number how fast they move
---@field speed_rand number speed random factor
---@field move number movement speed
---@field move_rand number movement random factor
---@field sin_depth number depth of sine wave motion
---@field sin_depth_rand number sine depth random factor
---@field sin_speed number speed of sine wave motion
---@field sin_speed_rand number sine speed random factor
---@field split integer split into multiple dudes?
---@field aggro integer attack the player?
---@field evade integer evade the player?
---@overload fun(count? : integer, delay? : number, delay_rand? : number, speed? : number, speed_rand? : number, move? : number, move_rand? : number, sin_depth? : number, sin_depth_rand? : number, sin_speed? : number, sin_speed_rand? : number, split? : integer, aggro? : integer, evade? : integer): WAVEINFO
local WAVEINFO = common.class({
    __name = "WAVEINFO",

    ---@param self WAVEINFO
    ---@param count? integer
    ---@param delay? number
    ---@param delay_rand? number
    ---@param speed_? number
    ---@param speed_rand? number
    ---@param move? number
    ---@param move_rand? number
    ---@param sin_depth? number
    ---@param sin_depth_rand? number
    ---@param sin_speed? number
    ---@param sin_speed_rand? number
    ---@param split? integer
    ---@param aggro? integer
    ---@param evade? integer
    __init__ = function(self, count, delay, delay_rand, speed_, speed_rand, move, move_rand, sin_depth, sin_depth_rand,
                        sin_speed, sin_speed_rand, split, aggro, evade)
        if count == nil then count = 0 end
        if delay == nil then delay = 0 end
        if delay_rand == nil then delay_rand = 0 end
        if speed_ == nil then speed_ = 0 end
        if speed_rand == nil then speed_rand = 0 end
        if move == nil then move = 0 end
        if move_rand == nil then move_rand = 0 end
        if sin_depth == nil then sin_depth = 0 end
        if sin_depth_rand == nil then sin_depth_rand = 0 end
        if sin_speed == nil then sin_speed = 0 end
        if sin_speed_rand == nil then sin_speed_rand = 0 end
        if split == nil then split = 0 end
        if aggro == nil then aggro = 0 end
        if evade == nil then evade = 0 end

        self.count = count
        self.delay = delay
        self.delay_rand = delay_rand
        self.speed = speed_
        self.speed_rand = speed_rand
        self.move = move
        self.move_rand = move_rand
        self.sin_depth = sin_depth
        self.sin_depth_rand = sin_depth_rand
        self.sin_speed = sin_speed
        self.sin_speed_rand = sin_speed_rand
        self.split = split
        self.aggro = aggro
        self.evade = evade
    end
})



local END_WAVEINFO = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }



--[[ attack wave #1 (straight downwards) --]]
local wave1 = new_table(WAVEINFO, {
    --[[ c  del  rnd  speed   r  mv r  dp r  sd r  sp ag ev --]]
    { 4, 0.0, 1.0, 0.0015, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0 },
    { 2, 0.7, 0.0, 0.0055, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    { 2, 0.5, 0.0, 0.0045, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    { 4, 0.0, 1.0, 0.0035, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    { 4, 0.0, 1.0, 0.0025, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    END_WAVEINFO
})



--[[ attack wave #2 (diagonal motion) --]]
local wave2 = new_table(WAVEINFO, {
    --[[ c  del  rnd  speed   rnd     move    rnd    dp r  sd r  sp ag ev --]]
    { 6, 2.0, 1.0, 0.0025, 0.002, 0.0000,  0.020, 0, 0, 0, 0, 0, 0, 0 },
    { 6, 1.2, 1.0, 0.0025, 0.001, 0.0000,  0.010, 0, 0, 0, 0, 0, 0, 0 },
    { 6, 0.5, 1.0, 0.0025, 0.000, 0.0000,  0.005, 0, 0, 0, 0, 0, 0, 0 },
    { 4, 0.0, 1.0, 0.0025, 0.000, -0.0025, 0.000, 0, 0, 0, 0, 0, 0, 0 },
    { 4, 0.0, 1.0, 0.0025, 0.000, 0.0025,  0.000, 0, 0, 0, 0, 0, 0, 0 },
    END_WAVEINFO
})



--[[ attack wave #3 (sine wave motion) --]]
local wave3 = new_table(WAVEINFO, {
    --[[ c  del  rnd  speed   rnd     mv r  sdepth rnd    sspd   rnd   sp ag ev --]]
    { 4, 0.0, 2.0, 0.0020, 0.0000, 0, 0, 0.005, 0.000, 0.020, 0.00, 1, 0, 0 },
    { 4, 1.5, 1.0, 0.0016, 0.0024, 0, 0, 0.002, 0.006, 0.010, 0.03, 0, 0, 0 },
    { 4, 1.0, 1.0, 0.0019, 0.0016, 0, 0, 0.003, 0.004, 0.015, 0.02, 0, 0, 0 },
    { 4, 0.5, 1.0, 0.0022, 0.0008, 0, 0, 0.004, 0.002, 0.020, 0.01, 0, 0, 0 },
    { 4, 0.0, 1.0, 0.0025, 0.0000, 0, 0, 0.005, 0.000, 0.025, 0.00, 0, 0, 0 },
    END_WAVEINFO
})



--[[ attack wave #4 (evade you) --]]
local wave4 = new_table(WAVEINFO, {
    --[[ c  del  rnd  speed   rnd     mv rnd    dp r  sd r  sp ag ev --]]
    { 4, 0.0, 2.0, 0.0020, 0.0000, 0, 0.000, 0, 0, 0, 0, 1, 0, 1 },
    { 3, 1.5, 1.0, 0.0016, 0.0024, 0, 0.010, 0, 0, 0, 0, 0, 0, 1 },
    { 3, 1.0, 1.0, 0.0019, 0.0016, 0, 0.001, 0, 0, 0, 0, 0, 0, 1 },
    { 4, 0.5, 1.0, 0.0022, 0.0008, 0, 0.000, 0, 0, 0, 0, 0, 0, 1 },
    { 4, 0.0, 1.0, 0.0025, 0.0000, 0, 0.000, 0, 0, 0, 0, 0, 0, 1 },
    END_WAVEINFO
})



--[[ attack wave #5 (attack you) --]]
local wave5 = new_table(WAVEINFO, {
    --[[ c  del  rnd  speed   rnd     mv rnd    sd r  sd r  sp ag ev --]]
    { 4, 0.0, 2.0, 0.0010, 0.0000, 0, 0.000, 0, 0, 0, 0, 1, 1, 0 },
    { 3, 1.5, 1.0, 0.0016, 0.0024, 0, 0.010, 0, 0, 0, 0, 0, 1, 0 },
    { 3, 1.0, 1.0, 0.0019, 0.0016, 0, 0.001, 0, 0, 0, 0, 0, 1, 0 },
    { 3, 0.5, 1.0, 0.0022, 0.0008, 0, 0.000, 0, 0, 0, 0, 0, 1, 0 },
    { 4, 0.0, 1.0, 0.0025, 0.0000, 0, 0.000, 0, 0, 0, 0, 0, 1, 0 },
    END_WAVEINFO
})



--[[ attack wave #6 (the boss wave, muahaha) --]]
local wave6 = new_table(WAVEINFO, {
    --[[ c  del  rnd  speed  rnd    mv rnd   dp rnd    sd rnd   sp ag ev --]]
    { 8, 6.0, 2.0, 0.002, 0.001, 0, 0.00, 0, 0,     0, 0,    1, 1, 0 },
    { 8, 4.5, 2.0, 0.002, 0.001, 0, 0.00, 0, 0,     0, 0,    1, 0, 1 },
    { 8, 3.0, 2.0, 0.002, 0.001, 0, 0.00, 0, 0.006, 0, 0.03, 1, 0, 0 },
    { 8, 1.5, 2.0, 0.002, 0.001, 0, 0.01, 0, 0,     0, 0,    1, 0, 0 },
    { 8, 0.0, 2.0, 0.002, 0.001, 0, 0.00, 0, 0,     0, 0,    1, 0, 0 },
    END_WAVEINFO
})



---@generic T
---@param tbl T[]
---@param start integer
---@return T[]
local function slice(tbl, start)
    local sliced = {}
    local begin = start + INDEX_BASE

    for i = begin, #tbl do
        sliced[i - begin + 1] = tbl[i]
    end

    return sliced
end



--[[ list of available attack waves --]]
---@type WAVEINFO[][]
local waveinfo = {
    slice(wave1, 4), slice(wave2, 4), slice(wave3, 4), slice(wave4, 4), slice(wave5, 4),
    slice(wave1, 3), slice(wave2, 3), slice(wave3, 3), slice(wave4, 3), slice(wave5, 3),
    slice(wave1, 2), slice(wave2, 2), slice(wave3, 2), slice(wave4, 2), slice(wave5, 2),
    slice(wave1, 1), slice(wave2, 1), slice(wave3, 1), slice(wave4, 1), slice(wave5, 1),
    slice(wave1, 0), slice(wave2, 0), slice(wave3, 0), slice(wave4, 0), slice(wave5, 0),
    wave6
}



--[[ info about someone nasty --]]
---@class BADGUY
---@field x number x position
---@field y number y position
---@field speed number vertical speed
---@field move number horizontal motion
---@field sin_depth number depth of sine motion
---@field sin_speed number speed of sine motion
---@field split integer whether to split ourselves
---@field aggro integer whether to attack the player
---@field evade integer whether to evade the player
---@field v number horizontal velocity
---@field t integer integer counter
---@field next BADGUY?
---@overload fun(x? : number, y? : number, speed? : number, move? : number, sin_depth? : number, sin_speed? : number, split? : integer, aggro? : integer, evade? : integer, v? : number, t? : integer, next? : BADGUY): BADGUY
local BADGUY = common.class({
    __name = "BADGUY",

    ---@param self BADGUY
    ---@param x? number
    ---@param y? number
    ---@param speed_? number
    ---@param move? number
    ---@param sin_depth? number
    ---@param sin_speed? number
    ---@param split? integer
    ---@param aggro? integer
    ---@param evade? integer
    ---@param v? number
    ---@param t? integer
    ---@param next? BADGUY
    __init__ = function(self, x, y, speed_, move, sin_depth, sin_speed, split, aggro, evade, v, t, next)
        if x == nil then x = 0 end
        if y == nil then y = 0 end
        if speed_ == nil then speed_ = 0 end
        if move == nil then move = 0 end
        if sin_depth == nil then sin_depth = 0 end
        if sin_speed == nil then sin_speed = 0 end
        if split == nil then split = 0 end
        if aggro == nil then aggro = 0 end
        if evade == nil then evade = 0 end
        if v == nil then v = 0 end
        if t == nil then t = 0 end
        self.x = x
        self.y = y
        self.speed = speed_
        self.move = move
        self.sin_depth = sin_depth
        self.sin_speed = sin_speed
        self.split = split
        self.aggro = aggro
        self.evade = evade
        self.v = v
        self.t = t
        self.next = next
    end
})

---@param self BADGUY
---@return BADGUY
function BADGUY.clone(self)
    local clone = BADGUY()

    clone.x = self.x
    clone.y = self.y
    clone.speed = self.speed
    clone.move = self.move
    clone.sin_depth = self.sin_depth
    clone.sin_speed = self.sin_speed
    clone.split = self.split
    clone.aggro = self.aggro
    clone.evade = self.evade
    clone.v = self.v
    clone.t = self.t
    clone.next = self.next

    return clone
end

local evildudes ---@type BADGUY?

local finished_counter = 0 ---@type integer

local wavenum = 0 ---@type integer



---@return number
local function URAND()
    return bit.band(rand(), 255) / 255.0
end

---@return number
local function SRAND()
    return bit.band(rand(), 255) / 255.0 - 0.5
end


--[[ creates a new swarm of badguys --]]
---@param reset boolean
local function lay_attack_wave(reset)
    if reset then
        wavenum = 0
    else
        wavenum = wavenum + 1
        if wavenum >= #waveinfo then
            wavenum = 0
        end
    end

    for _, info in ipairs(waveinfo[wavenum + INDEX_BASE]) do
        if info.count == 0 then
            break
        end

        for _ = 1, info.count do
            local b = BADGUY()

            b.x = URAND()
            b.y = -info.delay - URAND() * info.delay_rand
            b.speed = info.speed + URAND() * info.speed_rand
            b.move = info.move + SRAND() * info.move_rand
            b.sin_depth = info.sin_depth + URAND() * info.sin_depth_rand
            b.sin_speed = info.sin_speed + URAND() * info.sin_speed_rand
            b.split = info.split
            b.aggro = info.aggro
            b.evade = info.evade
            b.v = 0
            b.t = bit.band(rand(), 255)

            b.next = evildudes
            evildudes = b
        end
    end

    finished_counter = 0
end
exports.lay_attack_wave = lay_attack_wave



--[[ initialises the badguy functions --]]
local function init_badguys()
    evildudes = nil

    lay_attack_wave(true)
end
exports.init_badguys = init_badguys



--[[ closes down the badguys module --]]
local function shutdown_badguys()
    local b ---@type BADGUY

    while evildudes do
        b = evildudes
        evildudes = evildudes.next
        -- free(b)
        b.next = nil
    end
end
exports.shutdown_badguys = shutdown_badguys


---@param value BADGUY
local function evildudes_setter(value)
    evildudes = value
end

---@param self BADGUY
---@return fun(value : BADGUY)
local function next_setter(self)
    ---@param value BADGUY
    return function(value)
        self.next = value
    end
end


--[[ updates the badguy position --]]
local function update_badguys()
    local p = evildudes_setter ---@type fun(value : BADGUY)
    local b = evildudes ---@type BADGUY?
    local tmp1, tmp2 = nil, nil ---@type BADGUY?, BADGUY?
    local bullet ---@type BULLET?
    local x, y, d = 0, 0, 0 ---@type number, number, number
    local dead = false ---@type boolean

    --[[ testcode: enter clears the level --]]
    if (speed.cheat) and (key[allegro5.ALLEGRO_KEY_ENTER]) then
        shutdown_badguys()
        b = nil

        while key[allegro5.ALLEGRO_KEY_ENTER] do
            poll_input_wait()
        end
    end

    while b do
        dead = false

        if b.aggro ~= 0 then
            --[[ attack the player --]]
            d = player_pos() - b.x

            if d < -0.5 then
                d = d + 1 ---@type number
            elseif d > 0.5 then
                d = d - 1 ---@type number
            end

            if b.y < 0.5 then
                d = -d
            end

            b.v = b.v * (0.99)
            b.v = b.v + (SGN(d) * 0.00025)
        elseif b.evade ~= 0 then
            --[[ evade the player --]]
            if b.y < 0.75 then
                d = player_pos() + 0.5
            else
                d = b.x
            end

            if b.move then
                d = d + (SGN(b.move) / 16.0) ---@type number
            end

            d = find_target(d) - b.x

            if d < -0.5 then
                d = d + (1)
            elseif d > 0.5 then
                d = d - (1)
            end

            b.v = b.v * (0.96)
            b.v = b.v + (SGN(d) * 0.0004)
        end

        --[[ horizontal move --]]
        b.x = b.x + (b.move + sin(b.t * b.sin_speed) * b.sin_depth + b.v)

        if b.x < 0 then
            b.x = b.x + (1)
        elseif b.x > 1 then
            b.x = b.x - (1)
        end

        --[[ vertical move --]]
        b.y = b.y + (b.speed)

        if (b.y > 0.5) and (b.y - b.speed <= 0.5) and (b.split ~= 0) then
            --[[ split ourselves --]]
            tmp2 = b:clone()
            tmp1 = b:clone()

            tmp1.move = tmp1.move - (0.001)
            tmp2.move = tmp2.move + (0.001)

            b.speed = b.speed + (0.001)

            tmp1.t = bit.band(rand(), 255)
            tmp2.t = bit.band(rand(), 255)

            tmp1.next = tmp2
            tmp2.next = evildudes
            evildudes = tmp1
        end

        b.t = b.t + 1

        if b.y > 0 then
            if kill_player(b.x, b.y) then
                --[[ did we hit someone? --]]
                dead = true
            else
                --[[ or did someone else hit us? --]]
                bullet, x, y = get_first_bullet()

                while bullet do
                    x = x - b.x

                    if x < -0.5 then
                        x = x + (1)
                    elseif x > 0.5 then
                        x = x - (1)
                    end

                    x = ABS(x)

                    y = ABS(y - b.y)

                    if x < y then
                        d = y / 2 + x
                    else
                        d = x / 2 + y
                    end

                    if d < 0.025 then
                        kill_bullet(bullet)
                        explode(b.x, b.y, 0)
                        sfx_explode_alien()
                        dead = true
                        break
                    end

                    bullet, x, y = get_next_bullet(bullet)
                end
            end
        end

        --[[ advance to the next dude --]]
        if dead then
            p(b.next)
            tmp1 = b
            b = b.next
            -- free(tmp1)
            tmp1.next = nil
        else
            p = next_setter(b)
            b = b.next
        end
    end

    if (not evildudes) and (not player_dying()) then
        if finished_counter == 0 then
            message("Wave Complete")
            sfx_ping(0)
        end

        finished_counter = finished_counter + 1 ---@type integer

        if finished_counter > 64 then
            return true
        end
    end

    return false
end
exports.update_badguys = update_badguys



--[[ draws the badguys --]]
---@param r integer
---@param g integer
---@param b integer
---@param project fun(f : number[], i : integer[], c : integer) : boolean
local function draw_badguys(r, g, b, project)
    local bad = evildudes ---@type BADGUY?
    local c = makecol(r, g, b)
    local shape = new_table(0, 12) ---@type number[]
    local ishape = new_table(0, 12) ---@type integer[]

    while bad do
        if bad.y > 0 then
            shape[0 + INDEX_BASE] = bad.x - 0.02
            shape[1 + INDEX_BASE] = bad.y + 0.01

            shape[2 + INDEX_BASE] = bad.x
            shape[3 + INDEX_BASE] = bad.y + 0.02

            shape[4 + INDEX_BASE] = bad.x + 0.02
            shape[5 + INDEX_BASE] = bad.y + 0.01

            shape[6 + INDEX_BASE] = bad.x + 0.01
            shape[7 + INDEX_BASE] = bad.y + 0.005

            shape[8 + INDEX_BASE] = bad.x
            shape[9 + INDEX_BASE] = bad.y - 0.015

            shape[10 + INDEX_BASE] = bad.x - 0.01
            shape[11 + INDEX_BASE] = bad.y + 0.005

            if project(shape, ishape, 12) then
                polygon(6, ishape, c)
            end
        end

        bad = bad.next ---@type BADGUY?
    end
end
exports.draw_badguys = draw_badguys

return exports
