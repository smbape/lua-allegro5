local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/shooter/expl.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local a4_aux = require("demos.speed.a4_aux")
local data_m = require("data")

local new_array = common.new_array
local new_table = common.new_table
local pointer_cast = common.pointer_cast

local INDEX_BASE = 1 -- lua is 1-based indexed

local memcpy = allegro5_lua.C.memcpy

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi") ---@diagnostic disable-line: no-unknown
    memcpy = ffi.C.memcpy ---@type function
end

local ABS = a4_aux.ABS
local AL_RAND = a4_aux.AL_RAND

local GAME_PAL = data_m.GAME_PAL
local data = data_m.data

--[[ explosion graphics --]]
local EXPLODE_FLAG = 100; exports.EXPLODE_FLAG = EXPLODE_FLAG
local EXPLODE_FRAMES = 64; exports.EXPLODE_FRAMES = EXPLODE_FRAMES
local EXPLODE_SIZE = 160; exports.EXPLODE_SIZE = EXPLODE_SIZE

local explosion ---@type ALLEGRO_BITMAP[]

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/shooter/expl.c
--]]

explosion = {}
exports.explosion = explosion

---@class HOTSPOT
---@field x integer
---@field y integer
---@field xc integer
---@field yc integer
---@overload fun(x? : integer, y? : integer, xc? : integer, yc? : integer): HOTSPOT
local HOTSPOT = common.class({
    __name = "HOTSPOT",

    ---@param self HOTSPOT
    ---@param x? integer
    ---@param y? integer
    ---@param xc? integer
    ---@param yc? integer
    __init__ = function(self, x, y, xc, yc)
        if x == nil then x = 0 end
        if y == nil then y = 0 end
        if xc == nil then xc = 0 end
        if yc == nil then yc = 0 end
        self.x = x
        self.y = y
        self.xc = xc
        self.yc = yc
    end
})

--[[ the explosion graphics are pregenerated, using a simple particle system --]]
local function generate_explosions()
    local bmp = new_table(0, EXPLODE_SIZE * EXPLODE_SIZE)

    local HOTSPOTS = 128
    local hot = new_table(HOTSPOT, HOTSPOTS)

    for c = 1, HOTSPOTS do
        hot[c].x = bit.lshift(math.floor(EXPLODE_SIZE / 2), 16)
        hot[c].y = hot[c].x
        hot[c].xc = bit.band(AL_RAND(), 0x1FFFF) - 0xFFFF
        hot[c].yc = bit.band(AL_RAND(), 0x1FFFF) - 0xFFFF
    end

    for c = 0, EXPLODE_FRAMES - INDEX_BASE do
        for i = 1 , EXPLODE_SIZE * EXPLODE_SIZE do
            bmp[i] = 0
        end

        local color = bit.rshift((function() if (c < 16) then return c * 4 else return (80 - c) end end)(), 2) ---@type integer

        for c2 = 1, HOTSPOTS do
            for x = -12, 12 do
                for y = -12, 12 do
                    local xx = bit.rshift(hot[c2].x, 16) + x ---@type integer
                    local yy = bit.rshift(hot[c2].y, 16) + y ---@type integer
                    if (xx > 0) and (yy > 0) and (xx < EXPLODE_SIZE) and (yy < EXPLODE_SIZE) then
                        local p = yy * EXPLODE_SIZE + xx
                        bmp[p + INDEX_BASE] = bmp[p + INDEX_BASE]  + bit.rshift(color , math.floor((ABS(x) + ABS(y)) / 3))
                        if bmp[p + INDEX_BASE] > 63 then
                           bmp[p + INDEX_BASE] = 63
                        end
                    end
                end
            end
            hot[c2].x = hot[c2].x + hot[c2].xc
            hot[c2].y = hot[c2].y + hot[c2].yc
        end

        explosion[c + INDEX_BASE] = allegro5.al_create_bitmap(EXPLODE_SIZE, EXPLODE_SIZE)

        local locked = allegro5.al_lock_bitmap(explosion[c + INDEX_BASE], allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_8888_LE,
            allegro5.ALLEGRO_LOCK_WRITEONLY) --[[@as ALLEGRO_LOCKED_REGION --]]
        local locked_data = pointer_cast("uint8_t", locked.data)
        local locked_pitch = locked.pitch

        local pal = data[GAME_PAL + INDEX_BASE].dat ---@type PALETTE

        local use_c_api = allegro5 == allegro5_lua.allegro5
        local image_vector, image_row_size, image_data ---@type userdata, integer, number[]

        if use_c_api then
            image_data = {}
            for y = 0, EXPLODE_SIZE - INDEX_BASE do
                for x = 0, EXPLODE_SIZE - INDEX_BASE do
                    local c2 = bmp[y * EXPLODE_SIZE + x + INDEX_BASE] ---@type integer
                    if c2 < 8 then
                        c2 = 0 ---@type integer
                    else
                        c2 = 16 + math.floor(c2 / 4) ---@type integer
                    end

                    image_data[#image_data + 1] = pal.rgb[c2 + INDEX_BASE].r * 255
                    image_data[#image_data + 1] = pal.rgb[c2 + INDEX_BASE].g * 255
                    image_data[#image_data + 1] = pal.rgb[c2 + INDEX_BASE].b * 255
                    if c2 > 0 then
                        image_data[#image_data + 1] = pal.rgb[c2 + INDEX_BASE].a * 127
                    else
                        image_data[#image_data + 1] = 0
                    end
                end
            end
        end

        if use_c_api then
            image_vector = new_array("uint8_t", image_data)
            image_row_size = math.floor(image_vector:sizeof() / EXPLODE_SIZE)
        end

        for y = 0, EXPLODE_SIZE - INDEX_BASE do
            if use_c_api then
                local row = image_vector.ptr(locked_data, y * locked_pitch) ---@type lightuserdata
                local ptr = image_vector:ptr(y * image_row_size) ---@type lightuserdata
                memcpy(row, ptr, image_row_size)
            else
                for x = 0, EXPLODE_SIZE - INDEX_BASE do
                    local c2 = bmp[y * EXPLODE_SIZE + x + INDEX_BASE] ---@type integer
                    if c2 < 8 then
                        c2 = 0 ---@type integer
                    else
                        c2 = 16 + math.floor(c2 / 4) ---@type integer
                    end

                    local lp = locked_data + y * locked_pitch + x * 4 ---@type userdata
                    lp[0] = pal.rgb[c2 + INDEX_BASE].r * 255 ---@type number
                    lp[1] = pal.rgb[c2 + INDEX_BASE].g * 255 ---@type number
                    lp[2] = pal.rgb[c2 + INDEX_BASE].b * 255 ---@type number
                    if c2 > 0 then
                        lp[3] = pal.rgb[c2 + INDEX_BASE].a * 127 ---@type number
                    else
                        lp[3] = 0 ---@type number
                    end
                end
            end
        end


        allegro5.al_unlock_bitmap(explosion[c + INDEX_BASE])
    end
end
exports.generate_explosions = generate_explosions



local function destroy_explosions()
    for c = 0, EXPLODE_FRAMES - INDEX_BASE do
        allegro5.al_destroy_bitmap(explosion[c + INDEX_BASE])
    end
end
exports.destroy_explosions = destroy_explosions

return exports
