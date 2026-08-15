local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/speed/player.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local a4_aux = require("a4_aux")
local bullets = require("bullets")
local explode_m = require("explode")
local hiscore = require("hiscore")
local message_m = require("message")
local sound = require("sound")
local speed = require("speed")

local new_table = common.new_table

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local ABS = a4_aux.ABS

local key = a4_aux.key
local makecol = a4_aux.makecol
local poll_input = a4_aux.poll_input
local polygon = a4_aux.polygon

local fire_bullet = bullets.fire_bullet

local explode = explode_m.explode

local get_hiscore = hiscore.get_hiscore

local message = message_m.message

local sfx_explode_block = sound.sfx_explode_block
local sfx_explode_player = sound.sfx_explode_player
local sfx_ping = sound.sfx_ping


--[[
 -    SPEED - by Shawn Hargreaves, 1999
 -
 -    Main player control functions.
 --]]



--[[ how many lives do we have left? --]]
speed.lives = 0



--[[ counters for various time delays --]]
local init_time = 0 ---@type integer
local die_time = 0 ---@type integer
local fire_time = 0 ---@type integer



--[[ current position and velocity --]]
local pos = 0 ---@type number
local vel = 0 ---@type number



--[[ which segments of health we currently possess --]]
local SEGMENTS = 16 ---@type integer

local ganja = new_table(false, SEGMENTS) ---@type boolean[]

--[[ Did you ever come across a DOS shareware game called "Ganja Farmer"?
 - It is really very cool: you have to protect your crop from "Da Man",
 - who is trying to bomb it, spray it with defoliants, etc. Superb
 - reggae soundtrack, and the gameplay concept here is kind of similar,
 - hence my variable names...
 --]]



--[[ tell other people where we are --]]
---@return number
local function player_pos()
    return pos
end
exports.player_pos = player_pos



--[[ tell other people where to avoid us --]]
---@param x number
---@return number
local function find_target(x)
    local seg = math.floor(x * SEGMENTS) % SEGMENTS ---@type integer
    local j = 0 ---@type integer

    if seg < 0 then
        seg = seg + (SEGMENTS)
    end

    for i = 0, math.floor(SEGMENTS / 2) - INDEX_BASE do
        j = (seg + i) % SEGMENTS

        if ganja[j + INDEX_BASE] then
            return j / SEGMENTS + (0.5 / SEGMENTS)
        end

        j = (seg - i) % SEGMENTS
        if j < 0 then
            j = j + (SEGMENTS)
        end

        if ganja[j + INDEX_BASE] then
            return j / SEGMENTS + (0.5 / SEGMENTS)
        end
    end

    if pos < 0.5 then
        return pos + 0.5
    else
        return pos - 0.5
    end
end
exports.find_target = find_target



--[[ tell other people whether we are healthy --]]
---@return boolean
local function player_dying()
    return (die_time ~= 0) and (speed.lives <= 1)
end
exports.player_dying = player_dying



--[[ called by the badguys when they want to blow us up --]]
---@param x number
---@param y number
---@return boolean
local function kill_player(x, y)
    local ret = false

    if y >= 0.97 then
        local seg = math.floor(x * SEGMENTS) % SEGMENTS

        if ganja[seg + INDEX_BASE] then
            ganja[seg + INDEX_BASE] = false
            explode(x, 0.98, 1)
            sfx_explode_block()
        end

        ret = true
    end

    if (y >= 0.95) and (init_time == 0) and (die_time == 0) and (not speed.cheat) then
        local d = pos - x ---@type number
        if d < -0.5 then
            d = d + 1 ---@type number
        elseif d > 0.5 then
            d = d - 1 ---@type number
        end

        if ABS(d) < 0.06 then
            die_time = 128

            explode(x, 0.98, 2)
            explode(x, 0.98, 4)
            sfx_explode_player()

            message("Ship Destroyed")

            ret = true
        end
    end

    return ret
end
exports.kill_player = kill_player



--[[ initialises the player functions --]]
local function init_player()
    speed.lives = 3

    init_time = 128
    die_time = 0
    fire_time = 0

    pos = 0.5
    vel = 0

    for i = 0, SEGMENTS - INDEX_BASE do
        ganja[i + INDEX_BASE] = true
    end
end
exports.init_player = init_player



--[[ closes down the player module --]]
local function shutdown_player()
end
exports.shutdown_player = shutdown_player



--[[ advances the player to the next attack wave --]]
---@param cycle boolean
local function advance_player(cycle)
    local bonus = 0 ---@type integer
    local old_score = speed.score

    for i = 0, SEGMENTS - INDEX_BASE do
        if ganja[i + INDEX_BASE] then
            bonus = bonus + 1 ---@type integer
        else
            ganja[i + INDEX_BASE] = true
        end
    end

    if bonus == SEGMENTS then
        message("Bonus: 100")
        speed.score = speed.score + (100)
    end

    if cycle then
        message("Bonus: 1000")
        speed.score = speed.score + (1000)
    end

    local buf = string.format("Score: %d", bonus)
    message(buf)

    speed.score = speed.score + (bonus)

    if (get_hiscore() > 0) and (speed.score > get_hiscore()) and (old_score <= get_hiscore()) then
        message("New Record Score!")
        sfx_ping(3)
    elseif (bonus == SEGMENTS) or (cycle) then
        sfx_ping(1)
    end
end
exports.advance_player = advance_player



--[[ updates the player position --]]
local function update_player()
    poll_input()

    --[[ quit game? --]]
    if key[allegro5.ALLEGRO_KEY_ESCAPE] then
        return -1
    end

    --[[ safe period while initing --]]
    if init_time ~= 0 then
        init_time = init_time - 1 ---@type integer
    end

    --[[ blown up? --]]
    if die_time ~= 0 then
        die_time = die_time - 1

        if die_time == 0 then
            speed.lives = speed.lives - 1
            if speed.lives == 0 then
                return 1
            end

            init_time = 128
            pos = 0.5
            vel = 0

            if speed.lives == 1 then
                message("This Is Your Final Life")
            else
                message("One Life Remaining")
            end
        end
    end

    --[[ handle user left/right input --]]
    if die_time == 0 then
        if (a4_aux.joy_left) or (key[allegro5.ALLEGRO_KEY_LEFT]) then
            vel = vel - (0.005)
        end

        if (a4_aux.joy_right) or (key[allegro5.ALLEGRO_KEY_RIGHT]) then
            vel = vel + (0.005)
        end
    end

    --[[ move left and right --]]
    pos = pos + vel

    if pos >= 1.0 then
        pos = pos - 1.0 ---@type number
    end

    if pos < 0.0 then
        pos = pos + 1.0 ---@type number
    end

    vel = vel * 0.67

    --[[ fire bullets --]]
    if (die_time == 0) and (init_time == 0) and (fire_time == 0) then
        if (key[allegro5.ALLEGRO_KEY_SPACE]) or (a4_aux.joy_b1) then
            fire_bullet(pos)
            fire_time = 24
        end
    end

    if fire_time ~= 0 then
        fire_time = fire_time - 1 ---@type integer
    end

    return 0
end
exports.update_player = update_player



--[[ draws the player --]]
---@param r integer
---@param g integer
---@param b integer
---@param project fun(f : number[], i : integer[], c : integer) : boolean
local function draw_player(r, g, b, project)
    local shape = new_table(0.0, 12)
    local ishape = new_table(0, 12)

    --[[ draw health segments --]]
    for i = 0, SEGMENTS - INDEX_BASE do
        if ganja[i + INDEX_BASE] then
            shape[0 + INDEX_BASE] = i / SEGMENTS
            shape[1 + INDEX_BASE] = 0.98

            shape[2 + INDEX_BASE] = (i + 1) / SEGMENTS
            shape[3 + INDEX_BASE] = 0.98

            shape[4 + INDEX_BASE] = (i + 1) / SEGMENTS
            shape[5 + INDEX_BASE] = 1.0

            shape[6 + INDEX_BASE] = i / SEGMENTS
            shape[7 + INDEX_BASE] = 1.0

            if project(shape, ishape, 8) then
                polygon(4, ishape, makecol(math.floor(r / 3), math.floor(g / 3), math.floor(b / 3)))
            end
        end
    end

    --[[ flash on and off while initing, don't show while dead --]]
    if bit.band(init_time, 4) ~= 0 or (die_time ~= 0) then
        return
    end

    --[[ draw the ship --]]
    shape[0 + INDEX_BASE] = pos - 0.04
    shape[1 + INDEX_BASE] = 0.98

    shape[2 + INDEX_BASE] = pos - 0.02
    shape[3 + INDEX_BASE] = 0.97

    shape[4 + INDEX_BASE] = pos
    shape[5 + INDEX_BASE] = 0.95

    shape[6 + INDEX_BASE] = pos + 0.02
    shape[7 + INDEX_BASE] = 0.97

    shape[8 + INDEX_BASE] = pos + 0.04
    shape[9 + INDEX_BASE] = 0.98

    shape[10 + INDEX_BASE] = pos
    shape[11 + INDEX_BASE] = 0.98

    if project(shape, ishape, 12) then
        polygon(6, ishape, makecol(r, g, b))
    end
end
exports.draw_player = draw_player

return exports
