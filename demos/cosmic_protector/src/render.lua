local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/render.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local cosmic_protector = require("cosmic_protector")
local logic = require("logic")
local Game = require("Game")
local Resource = require("Resource")
local ResourceManager = require("ResourceManager").ResourceManager

local rand = common.rand

local entities = logic.entities

local randf = Game.randf

local RES_BACKGROUND = Resource.RES_BACKGROUND
local RES_INPUT = Resource.RES_INPUT
local RES_LARGEFONT = Resource.RES_LARGEFONT
local RES_PLAYER = Resource.RES_PLAYER

local cos = math.cos
local sin = math.sin

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/render.cpp
--]]

local waveAngle = 0.0 ---@type number
local waveBitmap ---@type ALLEGRO_BITMAP?
local bgx = 0 ---@type number
local bgy = 0 ---@type number
local shakeUpdateCount = 0 ---@type integer
local shakeCount = 0 ---@type integer
local SHAKE_TIME = 100 ---@type integer
local SHAKE_TIMES = 10 ---@type integer

local function renderWave()
    local w = allegro5.al_get_bitmap_width(waveBitmap)
    local h = allegro5.al_get_bitmap_height(waveBitmap)

    local a = waveAngle + allegro5.ALLEGRO_PI / 2

    local x = math.floor(cosmic_protector.BB_W / 2 + 64 * cos(a))
    local y = math.floor(cosmic_protector.BB_H / 2 + 64 * sin(a))

    allegro5.al_draw_rotated_bitmap(waveBitmap, w / 2, h,
        x, y, waveAngle, 0)
end

local function stopWave()
    waveAngle = 0.0
    allegro5.al_destroy_bitmap(waveBitmap)
    waveBitmap = nil
end

---@param num integer
local function showWave(num)
    if waveBitmap then
        stopWave()
    end

    local rm = ResourceManager.getInstance()

    local myfont = rm:getData(RES_LARGEFONT) ---@type ALLEGRO_FONT

    local text = string.format("WAVE %d", num)

    local w = allegro5.al_get_text_width(myfont, text)
    local h = allegro5.al_get_font_line_height(myfont)

    waveBitmap = allegro5.al_create_bitmap(w, h)
    local old_target = allegro5.al_get_target_bitmap()
    allegro5.al_set_target_bitmap(waveBitmap)
    allegro5.al_clear_to_color(allegro5.al_map_rgba(0, 0, 0, 0))
    allegro5.al_draw_textf(myfont, allegro5.al_map_rgb(255, 255, 255), 0, 0, 0, "%s", text)
    allegro5.al_set_target_bitmap(old_target)

    waveAngle = (allegro5.ALLEGRO_PI * 2)
end
exports.showWave = showWave

local function shake()
    shakeUpdateCount = SHAKE_TIME
    bgx = randf(0.0, 8.0)
    bgy = randf(0.0, 8.0)
    if rand() % 2 ~= 0 then
        bgx = -bgx ---@type number
    end
    if rand() % 2 ~= 0 then
        bgy = -bgy ---@type number
    end
end
exports.shake = shake

---@param step integer
local function render(step)
    if allegro5.ALLEGRO_IPHONE then
        if cosmic_protector.switched_out then
            return
        end
    end

    local rm = ResourceManager.getInstance()

    local bg = rm:getData(RES_BACKGROUND) ---@type ALLEGRO_BITMAP

    if shakeUpdateCount > 0 then
        shakeUpdateCount = shakeUpdateCount - (step) ---@type integer
        if shakeUpdateCount <= 0 then
            shakeCount = shakeCount + 1 ---@type integer
            if shakeCount >= SHAKE_TIMES then
                shakeCount = 0
                shakeUpdateCount = 0
                bgy = 0; bgx = bgy
            else
                bgx = randf(0.0, 8.0)
                bgy = randf(0.0, 8.0)
                if rand() % 2 ~= 0 then
                    bgx = -bgx ---@type number
                end
                if rand() % 2 ~= 0 then
                    bgy = -bgy ---@type number
                end
                shakeUpdateCount = SHAKE_TIME
            end
        end
    end

    allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))

    local h = allegro5.al_get_bitmap_height(bg)
    local w = allegro5.al_get_bitmap_width(bg)
    allegro5.al_draw_bitmap(bg, (cosmic_protector.BB_W - w) / 2 + bgx, (cosmic_protector.BB_H - h) / 2 + bgy, 0)

    for _, e in ipairs(entities) do
        e:render_four(allegro5.al_map_rgb(255, 255, 255))
        if e:isHighlighted() then
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_ONE)
            e:render_four(allegro5.al_map_rgb(150, 150, 150))
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
        end
    end

    local player = rm:getData(RES_PLAYER) ---@type Player
    player:render_four(allegro5.al_map_rgb(255, 255, 255))
    player:render_extra()

    if waveAngle > 0.0 then
        renderWave()
        waveAngle = waveAngle - (0.003 * step)
        if waveAngle <= 0.0 then
            stopWave()
        end
    end

    if allegro5.ALLEGRO_IPHONE then
        local input = rm:getData(RES_INPUT) ---@type Input
        input:draw()

        local xx = cosmic_protector.BB_W - 30
        local yy = 30

        allegro5.al_draw_line(xx - 10, yy - 10, xx + 10, yy + 10, allegro5.al_map_rgb(255, 255, 255), 4)
        allegro5.al_draw_line(xx - 10, yy + 10, xx + 10, yy - 10, allegro5.al_map_rgb(255, 255, 255), 4)
        allegro5.al_draw_circle(xx, yy, 20, allegro5.al_map_rgb(255, 255, 255), 4)
    end

    allegro5.al_flip_display()
end
exports.render = render

return exports
