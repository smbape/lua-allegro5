local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/speed/sound.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")

local new_table = common.new_table

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local pow = math.pow or function(x, y) return x ^ y end ---@diagnostic disable-line: deprecated

--[[ format: pitch, delay. Zero pitch = silence --]]


local part_1 =
{
    --[[ tune A bass --]]

    --[[ C --]] 45, 6, 0, 2,
    --[[ C --]] 45, 6, 0, 10,
    --[[ C --]] 45, 6, 0, 2,
    --[[ C --]] 45, 8, 0, 4,
    --[[ C --]] 45, 8, 0, 4,
    --[[ C --]] 45, 6, 0, 2,

    --[[ F --]] 50, 6, 0, 2,
    --[[ F --]] 50, 6, 0, 10,
    --[[ F --]] 50, 6, 0, 2,
    --[[ F --]] 50, 8, 0, 4,
    --[[ F --]] 50, 8, 0, 4,
    --[[ F --]] 50, 6, 0, 2,

    --[[ Ab --]] 53, 6, 0, 2,
    --[[ Ab --]] 53, 6, 0, 10,
    --[[ Ab --]] 53, 6, 0, 2,
    --[[ G --]] 52, 8, 0, 4,
    --[[ G --]] 52, 8, 0, 4,
    --[[ G --]] 52, 6, 0, 2,

    --[[ C --]] 45, 6, 0, 2,
    --[[ C --]] 45, 6, 0, 10,
    --[[ C --]] 45, 6, 0, 2,
    --[[ C --]] 45, 8, 0, 4,
    --[[ C --]] 45, 8, 0, 4,
    --[[ C --]] 45, 6, 0, 2,


    --[[ tune A repeat bass --]]

    --[[ C --]] 45, 6, 0, 2,
    --[[ C --]] 45, 6, 0, 10,
    --[[ C --]] 45, 6, 0, 2,
    --[[ C --]] 45, 8, 0, 4,
    --[[ C --]] 45, 8, 0, 4,
    --[[ C --]] 45, 6, 0, 2,

    --[[ F --]] 50, 6, 0, 2,
    --[[ F --]] 50, 6, 0, 10,
    --[[ F --]] 50, 6, 0, 2,
    --[[ F --]] 50, 8, 0, 4,
    --[[ F --]] 50, 8, 0, 4,
    --[[ F --]] 50, 6, 0, 2,

    --[[ Ab --]] 53, 6, 0, 2,
    --[[ Ab --]] 53, 6, 0, 10,
    --[[ Ab --]] 53, 6, 0, 2,
    --[[ G --]] 52, 8, 0, 4,
    --[[ G --]] 52, 8, 0, 4,
    --[[ G --]] 52, 6, 0, 2,

    --[[ C --]] 45, 6, 0, 2,
    --[[ C --]] 45, 6, 0, 10,
    --[[ C --]] 45, 6, 0, 2,
    --[[ C --]] 45, 8, 0, 4,
    --[[ C --]] 45, 8, 0, 4,
    --[[ C --]] 45, 6, 0, 2,


    --[[ tune B bass --]]

    --[[ C --]] 45, 52, 0, 4,
    --[[ C --]] 45, 6, 0, 2,

    --[[ D --]] 47, 52, 0, 4,
    --[[ D --]] 47, 6, 0, 2,

    --[[ Eb --]] 48, 14, 0, 2,
    --[[ F --]] 50, 14, 0, 2,
    --[[ G --]] 52, 14, 0, 2,
    --[[ Ab --]] 53, 14, 0, 2,

    --[[ Bb --]] 55, 6, 0, 2,
    --[[ Bb --]] 55, 6, 0, 10,
    --[[ Bb --]] 55, 6, 0, 2,
    --[[ C --]] 57, 14, 0, 2,
    --[[ G --]] 52, 14, 0, 2,


    --[[ tune B repeat bass --]]

    --[[ C --]] 45, 6, 0, 2,
    --[[ C --]] 45, 6, 0, 10,
    --[[ C --]] 45, 6, 0, 2,
    --[[ C --]] 45, 8, 0, 4,
    --[[ C --]] 45, 8, 0, 4,
    --[[ C --]] 45, 6, 0, 2,

    --[[ D --]] 47, 6, 0, 2,
    --[[ D --]] 47, 6, 0, 10,
    --[[ D --]] 47, 6, 0, 2,
    --[[ D --]] 47, 8, 0, 4,
    --[[ D --]] 47, 8, 0, 4,
    --[[ D --]] 47, 6, 0, 2,

    --[[ Eb --]] 48, 14, 0, 2,
    --[[ F --]] 50, 14, 0, 2,
    --[[ G --]] 52, 14, 0, 2,
    --[[ Ab --]] 53, 14, 0, 2,

    --[[ Bb --]] 55, 6, 0, 2,
    --[[ Bb --]] 55, 6, 0, 10,
    --[[ Bb --]] 55, 6, 0, 2,
    --[[ C --]] 57, 14, 0, 2,
    --[[ G --]] 52, 14, 0, 2,


    0, 0
}



local part_2 =
{
    --[[ tune A harmony --]]

    --[[ C --]] 57, 30, 0, 2,
    --[[ Eb --]] 60, 14, 0, 2,
    --[[ C --]] 57, 14, 0, 2,

    --[[ F --]] 62, 30, 0, 2,
    --[[ Ab --]] 65, 14, 0, 2,
    --[[ F --]] 62, 14, 0, 2,

    --[[ Ab --]] 65, 30, 0, 2,
    --[[ G --]] 64, 14, 0, 2,
    --[[ G --]] 52, 14, 0, 2,

    --[[ C --]] 57, 30, 0, 2,
    --[[ Eb --]] 60, 14, 0, 2,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ D --]] 59, 3, 0, 1,
    --[[ Db --]] 58, 3, 0, 1,
    --[[ C --]] 57, 3, 0, 1,


    --[[ tune A repeat harmony --]]

    --[[ C --]] 57, 3, 0, 1,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ G --]] 64, 3, 0, 1,
    --[[ C --]] 69, 6, 0, 2,
    --[[ C --]] 57, 3, 0, 1,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ G --]] 64, 3, 0, 1,
    --[[ C --]] 69, 6, 0, 6,
    --[[ C --]] 57, 3, 0, 1,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ G --]] 64, 3, 0, 1,
    --[[ C --]] 69, 6, 0, 2,

    --[[ C --]] 57, 3, 0, 1,
    --[[ F --]] 62, 3, 0, 1,
    --[[ Ab --]] 65, 3, 0, 1,
    --[[ C --]] 69, 6, 0, 2,
    --[[ C --]] 57, 3, 0, 1,
    --[[ F --]] 62, 3, 0, 1,
    --[[ Ab --]] 65, 3, 0, 1,
    --[[ C --]] 69, 6, 0, 6,
    --[[ C --]] 57, 3, 0, 1,
    --[[ F --]] 62, 3, 0, 1,
    --[[ Ab --]] 65, 3, 0, 1,
    --[[ C --]] 69, 6, 0, 2,

    --[[ C --]] 57, 3, 0, 1,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ Ab --]] 65, 3, 0, 1,
    --[[ C --]] 69, 6, 0, 2,
    --[[ C --]] 57, 3, 0, 1,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ Ab --]] 65, 3, 0, 1,
    --[[ C --]] 69, 6, 0, 6,
    --[[ C --]] 57, 3, 0, 1,
    --[[ D --]] 59, 3, 0, 1,
    --[[ G --]] 64, 3, 0, 1,
    --[[ D --]] 71, 6, 0, 2,

    --[[ C --]] 57, 3, 0, 1,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ G --]] 64, 3, 0, 1,
    --[[ C --]] 69, 6, 0, 2,
    --[[ C --]] 57, 3, 0, 1,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ G --]] 64, 3, 0, 1,
    --[[ C --]] 69, 6, 0, 6,
    --[[ C --]] 57, 3, 0, 1,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ G --]] 64, 3, 0, 1,
    --[[ C --]] 69, 6, 0, 2,


    --[[ tune B melody --]]

    --[[ C --]] 57, 3, 0, 1,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ F --]] 62, 3, 0, 1,
    --[[ G --]] 64, 5, 0, 3,
    --[[ Ab --]] 65, 3, 0, 1,
    --[[ F --]] 62, 5, 0, 3,
    --[[ G --]] 64, 3, 0, 1,
    --[[ Eb --]] 60, 5, 0, 3,
    --[[ F --]] 62, 3, 0, 1,
    --[[ D --]] 59, 5, 0, 3,
    --[[ Eb --]] 60, 5, 0, 3,

    --[[ D --]] 59, 3, 0, 1,
    --[[ F# --]] 63, 3, 0, 1,
    --[[ G --]] 64, 3, 0, 1,
    --[[ A --]] 66, 5, 0, 3,
    --[[ Bb --]] 67, 3, 0, 1,
    --[[ G --]] 64, 5, 0, 3,
    --[[ A --]] 66, 3, 0, 1,
    --[[ F# --]] 63, 5, 0, 3,
    --[[ G --]] 64, 3, 0, 1,
    --[[ Eb --]] 60, 5, 0, 3,
    --[[ F# --]] 63, 2, 0, 1,
    --[[ Eb --]] 60, 2, 0, 1,
    --[[ D --]] 59, 1, 0, 1,

    --[[ C --]] 57, 3, 0, 1,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ F --]] 62, 3, 0, 1,
    --[[ G --]] 64, 5, 0, 3,
    --[[ Ab --]] 65, 3, 0, 1,
    --[[ F --]] 62, 5, 0, 3,
    --[[ G --]] 64, 3, 0, 1,
    --[[ Eb --]] 60, 5, 0, 3,
    --[[ F --]] 62, 3, 0, 1,
    --[[ D --]] 59, 5, 0, 3,
    --[[ Eb --]] 60, 5, 0, 3,

    --[[ D --]] 59, 3, 0, 1,
    --[[ E --]] 61, 3, 0, 1,
    --[[ F# --]] 63, 3, 0, 1,
    --[[ Ab --]] 65, 5, 0, 3,
    --[[ F# --]] 63, 3, 0, 1,
    --[[ Ab --]] 65, 3, 0, 1,
    --[[ Bb --]] 67, 3, 0, 1,
    --[[ C --]] 69, 8, 0, 24,


    --[[ tune B repeat melody --]]

    --[[ C --]] 57, 3, 0, 1,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ F --]] 62, 3, 0, 1,
    --[[ G --]] 64, 5, 0, 3,
    --[[ Ab --]] 65, 3, 0, 1,
    --[[ F --]] 62, 5, 0, 3,
    --[[ G --]] 64, 3, 0, 1,
    --[[ Eb --]] 60, 5, 0, 3,
    --[[ F --]] 62, 3, 0, 1,
    --[[ D --]] 59, 5, 0, 3,
    --[[ Eb --]] 60, 5, 0, 3,

    --[[ D --]] 59, 3, 0, 1,
    --[[ F# --]] 63, 3, 0, 1,
    --[[ G --]] 64, 3, 0, 1,
    --[[ A --]] 66, 5, 0, 3,
    --[[ Bb --]] 67, 3, 0, 1,
    --[[ G --]] 64, 5, 0, 3,
    --[[ A --]] 66, 3, 0, 1,
    --[[ F# --]] 63, 5, 0, 3,
    --[[ G --]] 64, 3, 0, 1,
    --[[ Eb --]] 60, 5, 0, 3,
    --[[ F# --]] 63, 2, 0, 1,
    --[[ Eb --]] 60, 2, 0, 1,
    --[[ D --]] 59, 1, 0, 1,

    --[[ C --]] 57, 3, 0, 1,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ F --]] 62, 3, 0, 1,
    --[[ G --]] 64, 5, 0, 3,
    --[[ Ab --]] 65, 3, 0, 1,
    --[[ F --]] 62, 5, 0, 3,
    --[[ G --]] 64, 3, 0, 1,
    --[[ Eb --]] 60, 5, 0, 3,
    --[[ F --]] 62, 3, 0, 1,
    --[[ D --]] 59, 5, 0, 3,
    --[[ Eb --]] 60, 5, 0, 3,

    --[[ D --]] 59, 3, 0, 1,
    --[[ E --]] 61, 3, 0, 1,
    --[[ F# --]] 63, 3, 0, 1,
    --[[ Ab --]] 65, 5, 0, 3,
    --[[ F# --]] 63, 3, 0, 1,
    --[[ Ab --]] 65, 3, 0, 1,
    --[[ Bb --]] 67, 3, 0, 1,
    --[[ C --]] 69, 8, 0, 24,


    0, 0
}



local part_3 =
{
    --[[ tune A melody --]]

    --[[ G --]] 64, 3, 0, 1,
    --[[ G --]] 64, 3, 0, 1,
    --[[ Bb --]] 67, 3, 0, 1,
    --[[ C --]] 57, 5, 0, 3,
    --[[ C --]] 57, 3, 0, 1,
    --[[ D --]] 59, 3, 0, 1,
    --[[ C --]] 57, 3, 0, 1,
    --[[ Eb --]] 60, 5, 0, 3,
    --[[ Eb --]] 60, 5, 0, 3,
    --[[ D --]] 59, 4, 0, 1,
    --[[ C --]] 57, 4, 0, 1,
    --[[ Bb --]] 55, 5, 0, 5,

    --[[ G --]] 64, 3, 0, 1,
    --[[ G --]] 64, 3, 0, 1,
    --[[ Bb --]] 67, 3, 0, 1,
    --[[ C --]] 57, 8, 0, 4,
    --[[ D --]] 59, 5, 0, 3,
    --[[ C --]] 57, 5, 0, 3,
    --[[ Eb --]] 60, 5, 0, 3,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ D --]] 59, 3, 0, 1,
    --[[ C --]] 57, 3, 0, 9,

    --[[ G --]] 64, 3, 0, 1,
    --[[ G --]] 64, 3, 0, 1,
    --[[ Bb --]] 67, 3, 0, 1,
    --[[ C --]] 57, 5, 0, 3,
    --[[ D --]] 59, 5, 0, 3,
    --[[ C --]] 57, 5, 0, 3,
    --[[ Eb --]] 60, 5, 0, 3,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ D --]] 59, 3, 0, 1,
    --[[ C --]] 57, 3, 0, 1,

    --[[ G --]] 64, 5, 0, 3,
    --[[ G --]] 64, 5, 0, 3,
    --[[ Bb --]] 67, 5, 0, 3,
    --[[ C --]] 57, 8, 0, 32,


    --[[ tune A repeat melody --]]

    --[[ G --]] 64, 3, 0, 1,
    --[[ G --]] 64, 3, 0, 1,
    --[[ Bb --]] 67, 3, 0, 1,
    --[[ C --]] 57, 5, 0, 3,
    --[[ C --]] 57, 3, 0, 1,
    --[[ D --]] 59, 3, 0, 1,
    --[[ C --]] 57, 3, 0, 1,
    --[[ Eb --]] 60, 5, 0, 3,
    --[[ Eb --]] 60, 5, 0, 3,
    --[[ D --]] 59, 4, 0, 1,
    --[[ C --]] 57, 4, 0, 1,
    --[[ Bb --]] 55, 5, 0, 5,

    --[[ G --]] 64, 3, 0, 1,
    --[[ G --]] 64, 3, 0, 1,
    --[[ Bb --]] 67, 3, 0, 1,
    --[[ C --]] 57, 8, 0, 4,
    --[[ D --]] 59, 5, 0, 3,
    --[[ C --]] 57, 5, 0, 3,
    --[[ Eb --]] 60, 5, 0, 3,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ D --]] 59, 3, 0, 1,
    --[[ C --]] 57, 3, 0, 9,

    --[[ G --]] 64, 3, 0, 1,
    --[[ G --]] 64, 3, 0, 1,
    --[[ Bb --]] 67, 3, 0, 1,
    --[[ C --]] 57, 5, 0, 3,
    --[[ D --]] 59, 5, 0, 3,
    --[[ C --]] 57, 5, 0, 3,
    --[[ Eb --]] 60, 5, 0, 3,
    --[[ Eb --]] 60, 3, 0, 1,
    --[[ D --]] 59, 3, 0, 1,
    --[[ C --]] 57, 3, 0, 1,

    --[[ G --]] 64, 5, 0, 3,
    --[[ G --]] 64, 5, 0, 3,
    --[[ Bb --]] 67, 5, 0, 3,
    --[[ C --]] 57, 8, 0, 32,


    --[[ tune B harmony --]]

    --[[ C --]] 57, 52, 0, 4,
    --[[ C --]] 57, 6, 0, 2,

    --[[ D --]] 59, 52, 0, 4,
    --[[ D --]] 59, 6, 0, 2,

    --[[ Eb --]] 60, 14, 0, 2,
    --[[ F --]] 62, 14, 0, 2,
    --[[ G --]] 64, 14, 0, 2,
    --[[ Ab --]] 65, 14, 0, 2,

    --[[ Bb --]] 67, 6, 0, 2,
    --[[ Bb --]] 67, 6, 0, 10,
    --[[ Bb --]] 67, 6, 0, 2,
    --[[ C --]] 69, 14, 0, 2,
    --[[ G --]] 64, 2,
    --[[ F# --]] 63, 2,
    --[[ G --]] 64, 2,
    --[[ Ab --]] 65, 2,
    --[[ G --]] 64, 3, 0, 1,
    --[[ D --]] 59, 3, 0, 9,


    --[[ tune B repeat harmony --]]

    --[[ C --]] 57, 11, 0, 1,
    --[[ D --]] 59, 4, 0, 8,
    --[[ C --]] 57, 11, 0, 1,
    --[[ D --]] 59, 5, 0, 3,
    --[[ C --]] 57, 7, 0, 1,
    --[[ D --]] 59, 3, 0, 9,

    --[[ D --]] 59, 11, 0, 1,
    --[[ Eb --]] 60, 4, 0, 8,
    --[[ D --]] 59, 11, 0, 1,
    --[[ Eb --]] 60, 5, 0, 3,
    --[[ D --]] 59, 7, 0, 1,
    --[[ Eb --]] 60, 3, 0, 9,

    --[[ Eb --]] 60, 11, 0, 1,
    --[[ F --]] 62, 5, 0, 7,
    --[[ G --]] 64, 11, 0, 1,
    --[[ Ab --]] 65, 10, 0, 2,
    --[[ Bb --]] 67, 7, 0, 9,

    --[[ Bb --]] 67, 14, 0, 2,
    --[[ Bb --]] 67, 6, 0, 2,
    --[[ C --]] 69, 14, 0, 2,
    --[[ G --]] 64, 2,
    --[[ F# --]] 63, 2,
    --[[ G --]] 64, 2,
    --[[ Ab --]] 65, 2,
    --[[ G --]] 64, 3, 0, 1,
    --[[ D --]] 59, 3, 0, 1,


    0, 0
}



local part_4 =
{
    --[[ tune A drums --]]

    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 2, 4, 2, 4, 2, 2, 2, 2,


    --[[ tune A repeat drums --]]

    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 2, 4, 1, 4, 2, 2, 2, 2,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 2, 4, 1, 4, 2, 2, 2, 2,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 2, 4, 1, 4, 2, 2, 2, 2,
    1, 4, 3, 4, 2, 4, 3, 4,
    1, 4, 3, 4, 2, 4, 3, 4,
    2, 4, 1, 4, 1, 4, 2, 2, 2, 2,
    1, 4, 1, 4, 2, 2, 2, 2, 2, 2, 2, 2,


    --[[ tune B drums --]]

    1, 16, 1, 8, 1, 8,
    1, 16, 1, 8, 1, 4, 1, 4,
    1, 16, 1, 8, 1, 8,
    1, 16, 1, 8, 1, 4, 1, 4,
    1, 16, 1, 16, 1, 16, 1, 8, 1, 8,
    1, 8, 1, 8, 1, 4, 1, 4, 1, 4, 1, 4,
    1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2,
    1, 4, 2, 4, 2, 4, 2, 2, 2, 2,


    --[[ tune B repeat drums --]]
    1, 8, 2, 8, 1, 12, 1, 4,
    1, 16, 1, 4, 2, 4, 2, 4, 2, 2, 2, 2,
    1, 8, 2, 8, 1, 12, 1, 4,
    1, 16, 1, 4, 2, 4, 2, 4, 2, 2, 2, 2,
    1, 8, 2, 8, 1, 4, 1, 4, 2, 8,
    1, 8, 2, 8, 1, 4, 1, 4, 2, 8,
    1, 8, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 1, 4, 2, 4, 1, 4,
    2, 8, 1, 8, 1, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2,


    0, 0
}


---@param x integer
---@return number
local function PAN(x)
    return (x - 128) / 128.0
end

--[[ music player state --]]
local NUM_PARTS = 4

---@type integer[][]
local part_ptr =
{
    part_1, part_2, part_3, part_4
}

local part_pos_offset = new_table(0, NUM_PARTS)
local part_pos = {} ---@type integer[][]
local part_time = new_table(0, NUM_PARTS)

local freq_table = new_table(0, 256)

local part_voice = {} ---@type ALLEGRO_SAMPLE_INSTANCE[]

--[[ this code is sick --]]
---@param sine ALLEGRO_SAMPLE?
---@param square ALLEGRO_SAMPLE?
---@param saw ALLEGRO_SAMPLE?
---@param bd ALLEGRO_SAMPLE?
local function init_music(sine, square, saw, bd)
    --[[ start up the player --]]
    for i = 0, 256 - INDEX_BASE do
        freq_table[i + INDEX_BASE] = math.floor(350.0 * pow(2.0, i / 12.0))
    end

    for i = 0, NUM_PARTS - INDEX_BASE do
        part_pos_offset[i + INDEX_BASE] = 0
        part_pos[i + INDEX_BASE] = part_ptr[i + INDEX_BASE]
        part_time[i + INDEX_BASE] = 0
    end

    part_voice[0 + INDEX_BASE] = allegro5.al_create_sample_instance(sine)
    part_voice[1 + INDEX_BASE] = allegro5.al_create_sample_instance(square)
    part_voice[2 + INDEX_BASE] = allegro5.al_create_sample_instance(saw)
    part_voice[3 + INDEX_BASE] = allegro5.al_create_sample_instance(bd)

    allegro5.al_attach_sample_instance_to_mixer(part_voice[0 + INDEX_BASE], allegro5.al_get_default_mixer())
    allegro5.al_attach_sample_instance_to_mixer(part_voice[1 + INDEX_BASE], allegro5.al_get_default_mixer())
    allegro5.al_attach_sample_instance_to_mixer(part_voice[2 + INDEX_BASE], allegro5.al_get_default_mixer())
    allegro5.al_attach_sample_instance_to_mixer(part_voice[3 + INDEX_BASE], allegro5.al_get_default_mixer())

    allegro5.al_set_sample_instance_playmode(part_voice[0 + INDEX_BASE], allegro5.ALLEGRO_PLAYMODE_LOOP)
    allegro5.al_set_sample_instance_playmode(part_voice[1 + INDEX_BASE], allegro5.ALLEGRO_PLAYMODE_LOOP)
    allegro5.al_set_sample_instance_playmode(part_voice[2 + INDEX_BASE], allegro5.ALLEGRO_PLAYMODE_LOOP)
    allegro5.al_set_sample_instance_playmode(part_voice[3 + INDEX_BASE], allegro5.ALLEGRO_PLAYMODE_ONCE)

    allegro5.al_set_sample_instance_gain(part_voice[0 + INDEX_BASE], 192 / 255.0)
    allegro5.al_set_sample_instance_gain(part_voice[1 + INDEX_BASE], 192 / 255.0)
    allegro5.al_set_sample_instance_gain(part_voice[2 + INDEX_BASE], 192 / 255.0)
    allegro5.al_set_sample_instance_gain(part_voice[3 + INDEX_BASE], 255 / 255.0)

    allegro5.al_set_sample_instance_pan(part_voice[0 + INDEX_BASE], PAN(128))
    allegro5.al_set_sample_instance_pan(part_voice[1 + INDEX_BASE], PAN(224))
    allegro5.al_set_sample_instance_pan(part_voice[2 + INDEX_BASE], PAN(32))
    allegro5.al_set_sample_instance_pan(part_voice[3 + INDEX_BASE], PAN(128))
end
exports.init_music = init_music

local function shutdown_music()
    allegro5.al_destroy_sample_instance(part_voice[0 + INDEX_BASE])
    allegro5.al_destroy_sample_instance(part_voice[1 + INDEX_BASE])
    allegro5.al_destroy_sample_instance(part_voice[2 + INDEX_BASE])
    allegro5.al_destroy_sample_instance(part_voice[3 + INDEX_BASE])
end
exports.shutdown_music = shutdown_music

exports.part_ptr = part_ptr
exports.part_pos_offset = part_pos_offset
exports.part_pos = part_pos
exports.part_time = part_time
exports.freq_table = freq_table
exports.part_voice = part_voice

return exports
