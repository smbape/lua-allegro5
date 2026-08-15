local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/background_scroller.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local _global = require("global")
local demodata = require("demodata")

local DEMO_BMP_BACK = demodata.DEMO_BMP_BACK

local INDEX_BASE = 1 -- lua is 1-based indexed

local cos = math.cos
local sin = math.sin

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/background_scroller.c
--]]

---@type integer
local offx = 0

---@type integer
local offy = 0

---@type number
local current_time = 0

---@type number
local dt = 0

---@type ALLEGRO_BITMAP?
local tile

local function draw_background()
    local dx = allegro5.al_get_bitmap_width(tile)
    local dy = allegro5.al_get_bitmap_height(tile)

    while offx > 0 do
        offx = offx - dx
    end
    while offy > 0 do
        offy = offy - dy
    end

    local screen_width, screen_height = _global.screen_width, _global.screen_height

    for y = offy, screen_height, dy do
        if y >= screen_height then break end
        for x = offx, screen_width, dx do
            if x >= screen_width then break end
            allegro5.al_draw_bitmap(tile, x, y, 0)
        end
    end
end
exports.draw_background = draw_background


local function init_background()
    offx = 0
    offy = 0

    current_time = 0.0
    dt = 1.0 / _global.logic_framerate

    tile = _global.demo_data[DEMO_BMP_BACK + INDEX_BASE].dat
end
exports.init_background = init_background


local function update_background()
    --[[ increase time --]]
    current_time = current_time + dt

    --[[ calculate new offset from current current_time with some weird trig functions
      change the constants arbitrarily and/or add sin/cos components to
      get more complex animations --]]
    offx =
        math.floor(1.4 * allegro5.al_get_bitmap_width(tile) * sin(0.9 * current_time + 0.2) +
            0.3 * allegro5.al_get_bitmap_width(tile) * cos(1.5 * current_time - 0.4))
    offy =
        math.floor(0.6 * allegro5.al_get_bitmap_height(tile) * sin(1.2 * current_time - 0.7) -
            1.2 * allegro5.al_get_bitmap_height(tile) * cos(0.2 * current_time + 1.1))
end
exports.update_background = update_background

return exports
