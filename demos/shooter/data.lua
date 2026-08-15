local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/shooter/data.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local a4_aux = require("demos.speed.a4_aux")

local new_table = common.new_table

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local ALLEGRO_EXAMPLES_DATA_PATH = common.env.ALLEGRO_EXAMPLES_DATA_PATH
local ALLEGRO_DEMOS_SHOOTER_DATA_PATH = common.env.ALLEGRO_DEMOS_SHOOTER_DATA_PATH ---@type string?
local ALLEGRO_DEMOS_SKATER_DATA_PATH = common.env.ALLEGRO_DEMOS_SKATER_DATA_PATH ---@type string?

local DATAFILE = a4_aux.DATAFILE
local printf = a4_aux.printf

local PALETTE ---@class PALETTE

function exports.init()
    local demo = require("demo")
    PALETTE = demo.PALETTE ---@diagnostic disable-line: cast-local-type
end


--[[ Allegro datafile object indexes, produced by grabber v3.11 --]]
--[[ Datafile: e:\allegro\demo\demo.dat --]]
--[[ Date: Fri Apr  9 15:55:51 1999 --]]
--[[ Do not hand edit! --]]

local ASTA01      =  0 --[[ RLE --]]    ; exports.ASTA01 = ASTA01
local ASTA02      =  1 --[[ RLE --]]    ; exports.ASTA02 = ASTA02
local ASTA03      =  2 --[[ RLE --]]    ; exports.ASTA03 = ASTA03
local ASTA04      =  3 --[[ RLE --]]    ; exports.ASTA04 = ASTA04
local ASTA05      =  4 --[[ RLE --]]    ; exports.ASTA05 = ASTA05
local ASTA06      =  5 --[[ RLE --]]    ; exports.ASTA06 = ASTA06
local ASTA07      =  6 --[[ RLE --]]    ; exports.ASTA07 = ASTA07
local ASTA08      =  7 --[[ RLE --]]    ; exports.ASTA08 = ASTA08
local ASTA09      =  8 --[[ RLE --]]    ; exports.ASTA09 = ASTA09
local ASTA10      =  9 --[[ RLE --]]    ; exports.ASTA10 = ASTA10
local ASTA11      = 10 --[[ RLE --]]    ; exports.ASTA11 = ASTA11
local ASTA12      = 11 --[[ RLE --]]    ; exports.ASTA12 = ASTA12
local ASTA13      = 12 --[[ RLE --]]    ; exports.ASTA13 = ASTA13
local ASTA14      = 13 --[[ RLE --]]    ; exports.ASTA14 = ASTA14
local ASTA15      = 14 --[[ RLE --]]    ; exports.ASTA15 = ASTA15
local ASTB01      = 15 --[[ RLE --]]    ; exports.ASTB01 = ASTB01
local ASTB02      = 16 --[[ RLE --]]    ; exports.ASTB02 = ASTB02
local ASTB03      = 17 --[[ RLE --]]    ; exports.ASTB03 = ASTB03
local ASTB04      = 18 --[[ RLE --]]    ; exports.ASTB04 = ASTB04
local ASTB05      = 19 --[[ RLE --]]    ; exports.ASTB05 = ASTB05
local ASTB06      = 20 --[[ RLE --]]    ; exports.ASTB06 = ASTB06
local ASTB07      = 21 --[[ RLE --]]    ; exports.ASTB07 = ASTB07
local ASTB08      = 22 --[[ RLE --]]    ; exports.ASTB08 = ASTB08
local ASTB09      = 23 --[[ RLE --]]    ; exports.ASTB09 = ASTB09
local ASTB10      = 24 --[[ RLE --]]    ; exports.ASTB10 = ASTB10
local ASTB11      = 25 --[[ RLE --]]    ; exports.ASTB11 = ASTB11
local ASTB12      = 26 --[[ RLE --]]    ; exports.ASTB12 = ASTB12
local ASTB13      = 27 --[[ RLE --]]    ; exports.ASTB13 = ASTB13
local ASTB14      = 28 --[[ RLE --]]    ; exports.ASTB14 = ASTB14
local ASTB15      = 29 --[[ RLE --]]    ; exports.ASTB15 = ASTB15
local ASTC01      = 30 --[[ RLE --]]    ; exports.ASTC01 = ASTC01
local ASTC02      = 31 --[[ RLE --]]    ; exports.ASTC02 = ASTC02
local ASTC03      = 32 --[[ RLE --]]    ; exports.ASTC03 = ASTC03
local ASTC04      = 33 --[[ RLE --]]    ; exports.ASTC04 = ASTC04
local ASTC05      = 34 --[[ RLE --]]    ; exports.ASTC05 = ASTC05
local ASTC06      = 35 --[[ RLE --]]    ; exports.ASTC06 = ASTC06
local ASTC07      = 36 --[[ RLE --]]    ; exports.ASTC07 = ASTC07
local ASTC08      = 37 --[[ RLE --]]    ; exports.ASTC08 = ASTC08
local ASTC09      = 38 --[[ RLE --]]    ; exports.ASTC09 = ASTC09
local ASTC10      = 39 --[[ RLE --]]    ; exports.ASTC10 = ASTC10
local ASTC11      = 40 --[[ RLE --]]    ; exports.ASTC11 = ASTC11
local ASTC12      = 41 --[[ RLE --]]    ; exports.ASTC12 = ASTC12
local ASTC13      = 42 --[[ RLE --]]    ; exports.ASTC13 = ASTC13
local ASTC14      = 43 --[[ RLE --]]    ; exports.ASTC14 = ASTC14
local ASTC15      = 44 --[[ RLE --]]    ; exports.ASTC15 = ASTC15
local BOOM_SPL    = 45 --[[ SAMP --]]   ; exports.BOOM_SPL = BOOM_SPL
local DEATH_SPL   = 46 --[[ SAMP --]]   ; exports.DEATH_SPL = DEATH_SPL
local END_FONT    = 47 --[[ FONT --]]   ; exports.END_FONT = END_FONT
local ENGINE1     = 48 --[[ RLE --]]    ; exports.ENGINE1 = ENGINE1
local ENGINE2     = 49 --[[ RLE --]]    ; exports.ENGINE2 = ENGINE2
local ENGINE3     = 50 --[[ RLE --]]    ; exports.ENGINE3 = ENGINE3
local ENGINE4     = 51 --[[ RLE --]]    ; exports.ENGINE4 = ENGINE4
local ENGINE5     = 52 --[[ RLE --]]    ; exports.ENGINE5 = ENGINE5
local ENGINE6     = 53 --[[ RLE --]]    ; exports.ENGINE6 = ENGINE6
local ENGINE7     = 54 --[[ RLE --]]    ; exports.ENGINE7 = ENGINE7
local ENGINE_SPL  = 55 --[[ SAMP --]]   ; exports.ENGINE_SPL = ENGINE_SPL
local GAME_MUSIC  = 56 --[[ MIDI --]]   ; exports.GAME_MUSIC = GAME_MUSIC
local GAME_PAL    = 57 --[[ PAL --]]    ; exports.GAME_PAL = GAME_PAL
local GO_BMP      = 58 --[[ BMP --]]    ; exports.GO_BMP = GO_BMP
local INTRO_ANIM  = 59 --[[ FLIC --]]   ; exports.INTRO_ANIM = INTRO_ANIM
local INTRO_BMP_1 = 60 --[[ BMP --]]    ; exports.INTRO_BMP_1 = INTRO_BMP_1
local INTRO_BMP_2 = 61 --[[ BMP --]]    ; exports.INTRO_BMP_2 = INTRO_BMP_2
local INTRO_BMP_3 = 62 --[[ BMP --]]    ; exports.INTRO_BMP_3 = INTRO_BMP_3
local INTRO_BMP_4 = 63 --[[ BMP --]]    ; exports.INTRO_BMP_4 = INTRO_BMP_4
local INTRO_MUSIC = 64 --[[ MIDI --]]   ; exports.INTRO_MUSIC = INTRO_MUSIC
local INTRO_SPL   = 65 --[[ SAMP --]]   ; exports.INTRO_SPL = INTRO_SPL
local ROCKET      = 66 --[[ RLE --]]    ; exports.ROCKET = ROCKET
local SHIP1       = 67 --[[ RLE --]]    ; exports.SHIP1 = SHIP1
local SHIP2       = 68 --[[ RLE --]]    ; exports.SHIP2 = SHIP2
local SHIP3       = 69 --[[ RLE --]]    ; exports.SHIP3 = SHIP3
local SHIP4       = 70 --[[ RLE --]]    ; exports.SHIP4 = SHIP4
local SHIP5       = 71 --[[ RLE --]]    ; exports.SHIP5 = SHIP5
local SHOOT_SPL   = 72 --[[ SAMP --]]   ; exports.SHOOT_SPL = SHOOT_SPL
local TITLE_BMP   = 73 --[[ BMP --]]    ; exports.TITLE_BMP = TITLE_BMP
local TITLE_FONT  = 74 --[[ FONT --]]   ; exports.TITLE_FONT = TITLE_FONT
local TITLE_MUSIC = 75 --[[ MIDI --]]   ; exports.TITLE_MUSIC = TITLE_MUSIC
local TITLE_PAL   = 76 --[[ PAL --]]    ; exports.TITLE_PAL = TITLE_PAL
local WELCOME_SPL = 77 --[[ SAMP --]]   ; exports.WELCOME_SPL = WELCOME_SPL
local DATA_COUNT  = 78                  ; exports.DATA_COUNT = DATA_COUNT

local data ---@type DATAFILE[]

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/shooter/data.c
--]]

--[[ our graphics, samples, etc. --]]
data = new_table(DATAFILE, DATA_COUNT)
exports.data = data

local names = {
    "ASTA01",
    "ASTA02",
    "ASTA03",
    "ASTA04",
    "ASTA05",
    "ASTA06",
    "ASTA07",
    "ASTA08",
    "ASTA09",
    "ASTA10",
    "ASTA11",
    "ASTA12",
    "ASTA13",
    "ASTA14",
    "ASTA15",
    "ASTB01",
    "ASTB02",
    "ASTB03",
    "ASTB04",
    "ASTB05",
    "ASTB06",
    "ASTB07",
    "ASTB08",
    "ASTB09",
    "ASTB10",
    "ASTB11",
    "ASTB12",
    "ASTB13",
    "ASTB14",
    "ASTB15",
    "ASTC01",
    "ASTC02",
    "ASTC03",
    "ASTC04",
    "ASTC05",
    "ASTC06",
    "ASTC07",
    "ASTC08",
    "ASTC09",
    "ASTC10",
    "ASTC11",
    "ASTC12",
    "ASTC13",
    "ASTC14",
    "ASTC15",
    "BOOM_SPL",
    "DEATH_SPL",
    "END_FONT",
    "ENGINE1",
    "ENGINE2",
    "ENGINE3",
    "ENGINE4",
    "ENGINE5",
    "ENGINE6",
    "ENGINE7",
    "ENGINE_SPL",
    "GAME_MUSIC",
    "GAME_PAL",
    "GO_BMP",
    "INTRO_ANIM",
    "INTRO_BMP_1",
    "INTRO_BMP_2",
    "INTRO_BMP_3",
    "INTRO_BMP_4",
    "INTRO_MUSIC",
    "INTRO_SPL",
    "ROCKET",
    "SHIP1",
    "SHIP2",
    "SHIP3",
    "SHIP4",
    "SHIP5",
    "SHOOT_SPL",
    "TITLE_BMP",
    "TITLE_FONT",
    "TITLE_MUSIC",
    "TITLE_PAL",
    "WELCOME_SPL",
}

names[INTRO_MUSIC + INDEX_BASE] = "menu/intro_music"
names[TITLE_MUSIC + INDEX_BASE] = "menu/menu_music"

local title_pal ---@type integer[]
local game_pal ---@type integer[]
local ast ---@type ALLEGRO_BITMAP?

---@param pal integer[]
---@return PALETTE
local function _make_pal(pal)
    local p = PALETTE() ---@type PALETTE
    for i = 0, 256 - INDEX_BASE do
        p.rgb[i + INDEX_BASE] = allegro5.al_map_rgb(pal[i * 3 + 0 + INDEX_BASE], pal[i * 3 + 1 + INDEX_BASE],
            pal[i * 3 + 2 + INDEX_BASE])
    end
    return p
end

local function data_load()
    local name = ALLEGRO_DEMOS_SHOOTER_DATA_PATH .. "/AST.png" ---@type string

    ast = allegro5.al_load_bitmap(name)
    if not ast then
        printf("Could not load %s.\n", name)
    end

    for i = 0, DATA_COUNT - INDEX_BASE do
        name = names[i + INDEX_BASE] ---@type string

        if i == END_FONT or i == TITLE_FONT then
            name = ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf"
            data[i + INDEX_BASE].dat = allegro5.al_load_font(name, 24, 0)
        end
        if i == GAME_MUSIC then
            name = string.format(ALLEGRO_DEMOS_SHOOTER_DATA_PATH .. "/%s.ogg", names[i + INDEX_BASE])
            data[i + INDEX_BASE].dat = name
        end
        if i == TITLE_MUSIC or i == INTRO_MUSIC then
            name = string.format(ALLEGRO_DEMOS_SKATER_DATA_PATH .. "/%s.ogg", names[i + INDEX_BASE])
            data[i + INDEX_BASE].dat = name
        end
        if i == TITLE_PAL then
            data[i + INDEX_BASE].dat = _make_pal(title_pal)
        end
        if i == GAME_PAL then
            data[i + INDEX_BASE].dat = _make_pal(game_pal)
        end
        if i >= ASTA01 and i <= ASTC15 then
            local j = i - ASTA01 ---@type integer
            local x = j % 8 ---@type integer
            local y = math.floor(j / 8) ---@type integer
            data[i + INDEX_BASE].dat = allegro5.al_create_sub_bitmap(ast, x * 60, y * 60, 60, 60)
        end
        if not data[i + INDEX_BASE].dat then
            name = string.format(ALLEGRO_DEMOS_SHOOTER_DATA_PATH .. "/%s.png", names[i + INDEX_BASE])
            data[i + INDEX_BASE].dat = allegro5.al_load_bitmap(name)
        end
        if not data[i + INDEX_BASE].dat then
            name = string.format(ALLEGRO_DEMOS_SHOOTER_DATA_PATH .. "/%s.wav", names[i + INDEX_BASE])
            data[i + INDEX_BASE].dat = allegro5.al_load_sample(name)
        end
        if not data[i + INDEX_BASE].dat then
            printf("Could not load %s.\n", name)
        end
    end
end
exports.data_load = data_load



title_pal = {
    0, 0, 0,
    48, 48, 81,
    28, 28, 101,
    60, 60, 109,
    101, 101, 162,
    142, 142, 203,
    190, 190, 243,
    255, 255, 255,
    0, 0, 0,
    4, 0, 0,
    4, 0, 0,
    8, 0, 0,
    8, 0, 0,
    12, 0, 0,
    12, 0, 0,
    16, 0, 0,
    16, 0, 0,
    20, 0, 0,
    20, 0, 0,
    24, 0, 0,
    24, 0, 0,
    28, 0, 0,
    28, 0, 0,
    32, 0, 0,
    32, 0, 0,
    36, 0, 0,
    40, 0, 0,
    40, 0, 0,
    44, 0, 0,
    44, 0, 0,
    48, 0, 0,
    48, 0, 0,
    52, 0, 0,
    52, 0, 0,
    56, 0, 0,
    56, 0, 0,
    60, 0, 0,
    60, 0, 0,
    65, 0, 0,
    65, 0, 0,
    69, 0, 0,
    69, 0, 0,
    73, 0, 0,
    77, 0, 0,
    77, 0, 0,
    81, 0, 0,
    81, 0, 0,
    85, 0, 0,
    85, 0, 0,
    89, 0, 0,
    89, 0, 0,
    93, 0, 0,
    93, 0, 0,
    97, 0, 0,
    97, 0, 0,
    101, 0, 0,
    101, 0, 0,
    105, 0, 0,
    105, 0, 0,
    109, 0, 0,
    113, 0, 0,
    113, 0, 0,
    117, 0, 0,
    117, 0, 0,
    121, 0, 0,
    121, 0, 0,
    125, 0, 0,
    125, 0, 0,
    130, 0, 0,
    130, 0, 0,
    134, 0, 0,
    134, 0, 0,
    138, 0, 0,
    138, 0, 0,
    142, 0, 0,
    142, 0, 0,
    146, 0, 0,
    150, 0, 0,
    150, 0, 0,
    154, 0, 0,
    154, 0, 0,
    158, 0, 0,
    158, 0, 0,
    162, 0, 0,
    162, 0, 0,
    166, 0, 0,
    166, 0, 0,
    170, 0, 0,
    170, 0, 0,
    174, 0, 0,
    174, 0, 0,
    178, 0, 0,
    178, 0, 0,
    182, 0, 0,
    186, 0, 0,
    186, 0, 0,
    190, 0, 0,
    190, 0, 0,
    195, 0, 0,
    195, 0, 0,
    199, 0, 0,
    199, 0, 0,
    203, 0, 0,
    203, 0, 0,
    207, 0, 0,
    207, 0, 0,
    211, 0, 0,
    211, 0, 0,
    215, 0, 0,
    215, 0, 0,
    219, 0, 0,
    223, 0, 0,
    223, 0, 0,
    227, 0, 0,
    227, 0, 0,
    231, 0, 0,
    231, 0, 0,
    235, 0, 0,
    235, 0, 0,
    239, 0, 0,
    239, 0, 0,
    243, 0, 0,
    243, 0, 0,
    247, 0, 0,
    247, 0, 0,
    251, 0, 0,
    251, 0, 0,
    255, 0, 0,
    0, 0, 0,
    0, 0, 0,
    4, 4, 4,
    4, 4, 4,
    8, 8, 8,
    8, 8, 8,
    12, 12, 12,
    12, 12, 12,
    16, 16, 16,
    16, 16, 16,
    20, 20, 20,
    20, 20, 20,
    24, 24, 24,
    24, 24, 24,
    28, 28, 28,
    28, 28, 28,
    32, 32, 32,
    32, 32, 32,
    36, 36, 36,
    36, 36, 36,
    40, 40, 40,
    40, 40, 40,
    44, 44, 44,
    44, 44, 44,
    48, 48, 48,
    48, 48, 48,
    52, 52, 52,
    52, 52, 52,
    56, 56, 56,
    56, 56, 56,
    60, 60, 60,
    60, 60, 60,
    65, 65, 65,
    65, 65, 65,
    69, 69, 69,
    69, 69, 69,
    73, 73, 73,
    73, 73, 73,
    77, 77, 77,
    77, 77, 77,
    81, 81, 81,
    81, 81, 81,
    85, 85, 85,
    85, 85, 85,
    89, 89, 89,
    89, 89, 89,
    93, 93, 93,
    93, 93, 93,
    97, 97, 97,
    97, 97, 97,
    101, 101, 101,
    101, 101, 101,
    105, 105, 105,
    105, 105, 105,
    109, 109, 109,
    109, 109, 109,
    113, 113, 113,
    113, 113, 113,
    117, 117, 117,
    117, 117, 117,
    121, 121, 121,
    121, 121, 121,
    125, 125, 125,
    125, 125, 125,
    130, 130, 130,
    130, 130, 130,
    134, 134, 134,
    134, 134, 134,
    138, 138, 138,
    138, 138, 138,
    142, 142, 142,
    142, 142, 142,
    146, 146, 146,
    146, 146, 146,
    150, 150, 150,
    150, 150, 150,
    154, 154, 154,
    154, 154, 154,
    158, 158, 158,
    158, 158, 158,
    162, 162, 162,
    162, 162, 162,
    166, 166, 166,
    166, 166, 166,
    170, 170, 170,
    170, 170, 170,
    174, 174, 174,
    174, 174, 174,
    178, 178, 178,
    178, 178, 178,
    182, 182, 182,
    182, 182, 182,
    186, 186, 186,
    186, 186, 186,
    190, 190, 190,
    190, 190, 190,
    195, 195, 195,
    195, 195, 195,
    199, 199, 199,
    199, 199, 199,
    203, 203, 203,
    203, 203, 203,
    207, 207, 207,
    207, 207, 207,
    211, 211, 211,
    211, 211, 211,
    215, 215, 215,
    215, 215, 215,
    219, 219, 219,
    219, 219, 219,
    223, 223, 223,
    223, 223, 223,
    227, 227, 227,
    227, 227, 227,
    231, 231, 231,
    231, 231, 231,
    235, 235, 235,
    235, 235, 235,
    239, 239, 239,
    239, 239, 239,
    243, 243, 243,
    243, 243, 243,
    247, 247, 247,
    247, 247, 247,
    251, 251, 251,
    251, 251, 251,
    255, 255, 255,
    255, 255, 255,
}

game_pal = {
    0, 0, 0,
    255, 255, 255,
    0, 162, 255,
    0, 255, 0,
    255, 255, 0,
    255, 0, 0,
    0, 0, 0,
    162, 162, 162,
    0, 0, 117,
    0, 0, 162,
    0, 125, 211,
    130, 56, 255,
    0, 199, 255,
    130, 154, 195,
    223, 255, 186,
    255, 255, 255,
    0, 0, 0,
    16, 0, 0,
    44, 0, 0,
    73, 0, 0,
    101, 0, 0,
    130, 0, 0,
    162, 0, 0,
    195, 0, 0,
    227, 0, 0,
    255, 0, 0,
    255, 101, 0,
    255, 150, 0,
    255, 199, 0,
    255, 255, 0,
    255, 255, 125,
    255, 255, 255,
    93, 56, 12,
    101, 65, 16,
    73, 56, 36,
    109, 105, 77,
    125, 81, 24,
    97, 56, 12,
    255, 255, 65,
    52, 32, 8,
    93, 52, 16,
    117, 73, 20,
    130, 85, 24,
    73, 69, 48,
    48, 36, 24,
    44, 40, 28,
    255, 243, 56,
    69, 56, 36,
    73, 60, 40,
    85, 81, 60,
    142, 97, 28,
    121, 117, 85,
    150, 105, 28,
    101, 97, 69,
    60, 48, 28,
    101, 97, 73,
    65, 60, 44,
    146, 142, 105,
    77, 73, 52,
    32, 20, 4,
    40, 36, 24,
    121, 117, 89,
    138, 134, 97,
    142, 138, 101,
    121, 77, 20,
    8, 8, 4,
    81, 65, 40,
    8, 4, 4,
    81, 60, 40,
    85, 81, 56,
    89, 73, 48,
    77, 73, 56,
    48, 44, 32,
    52, 48, 36,
    255, 255, 73,
    113, 109, 81,
    255, 219, 52,
    56, 44, 24,
    40, 32, 20,
    125, 81, 20,
    186, 178, 134,
    56, 52, 40,
    150, 146, 105,
    89, 44, 8,
    182, 174, 130,
    162, 109, 32,
    125, 121, 89,
    138, 85, 24,
    89, 85, 65,
    255, 154, 16,
    255, 211, 48,
    130, 125, 93,
    109, 105, 81,
    65, 32, 4,
    117, 73, 24,
    255, 207, 48,
    134, 130, 93,
    154, 146, 109,
    56, 40, 20,
    36, 32, 24,
    60, 48, 32,
    97, 52, 16,
    162, 154, 113,
    166, 158, 121,
    0, 0, 0,
    60, 32, 4,
    158, 150, 113,
    97, 52, 12,
    65, 60, 48,
    130, 125, 89,
    93, 56, 16,
    113, 109, 77,
    81, 69, 48,
    12, 12, 8,
    146, 97, 28,
    77, 65, 44,
    146, 138, 101,
    73, 52, 32,
    16, 12, 8,
    28, 16, 4,
    125, 121, 85,
    130, 81, 20,
    12, 8, 0,
    101, 56, 16,
    130, 77, 20,
    255, 255, 60,
    20, 16, 8,
    65, 44, 24,
    52, 48, 32,
    81, 16, 0,
    52, 40, 20,
    158, 154, 113,
    134, 130, 97,
    85, 73, 44,
    65, 48, 24,
    16, 8, 0,
    121, 69, 16,
    36, 32, 20,
    89, 77, 56,
    142, 97, 24,
    109, 73, 20,
    255, 227, 56,
    32, 28, 16,
    52, 40, 24,
    134, 125, 97,
    255, 235, 52,
    65, 65, 44,
    255, 69, 8,
    81, 65, 36,
    44, 40, 32,
    113, 69, 24,
    130, 77, 24,
    255, 235, 56,
    255, 162, 16,
    52, 44, 32,
    109, 73, 16,
    97, 56, 16,
    166, 162, 117,
    138, 85, 20,
    52, 40, 28,
    65, 48, 28,
    142, 138, 105,
    109, 69, 24,
    77, 65, 36,
    255, 199, 48,
    73, 69, 52,
    255, 146, 16,
    60, 56, 36,
    134, 89, 20,
    24, 12, 0,
    69, 56, 40,
    255, 227, 52,
    138, 134, 93,
    255, 251, 60,
    255, 89, 16,
    85, 73, 48,
    158, 154, 109,
    150, 97, 32,
    255, 239, 56,
    73, 60, 48,
    150, 146, 109,
    73, 52, 24,
    121, 73, 20,
    65, 56, 40,
    255, 150, 16,
    255, 97, 8,
    255, 44, 4,
    16, 16, 12,
    56, 56, 36,
    255, 231, 56,
    56, 44, 28,
    255, 142, 16,
    255, 178, 16,
    255, 138, 16,
    16, 0, 0,
    255, 121, 16,
    255, 158, 16,
    255, 134, 16,
    255, 170, 16,
    16, 4, 0,
    255, 65, 8,
    20, 8, 0,
    48, 8, 0,
    255, 52, 8,
    255, 105, 12,
    56, 12, 0,
    255, 113, 16,
    24, 4, 0,
    255, 130, 16,
    40, 8, 0,
    255, 97, 16,
    28, 8, 0,
    65, 16, 0,
    32, 8, 0,
    255, 60, 8,
    255, 48, 4,
    255, 117, 16,
    255, 146, 12,
    73, 16, 0,
    24, 8, 0,
    255, 130, 12,
    255, 125, 16,
    255, 56, 8,
    255, 154, 12,
    36, 8, 0,
    32, 4, 0,
    255, 162, 12,
    255, 56, 4,
    255, 109, 16,
    65, 12, 0,
    255, 138, 12,
    44, 8, 0,
    40, 4, 0,
    255, 142, 12,
    255, 105, 16,
    255, 65, 4,
    81, 48, 174,
    174, 174, 81,
    0, 0, 0,
    0, 0, 0,
    0, 0, 0,
    0, 0, 0,
    65, 182, 65,
    52, 81, 81,
    109, 81, 182,
    81, 101, 247,
    113, 109, 97,
    215, 109, 113,
    0, 0, 0,
    0, 0, 0,
    0, 0, 0,
    0, 0, 0,
    203, 65, 203,
    154, 81, 81,
    215, 251, 166,
    0, 0, 0,
}

return exports
