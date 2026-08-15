local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/transition.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local _global = require("global")

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end


---@class TRANSITION
---@field from? GAMESTATE
---@field to? GAMESTATE
---@field duration number
---@field progress number
---@field from_bmp? ALLEGRO_BITMAP
---@field to_bmp? ALLEGRO_BITMAP
---@overload fun(from?:  GAMESTATE, to?:  GAMESTATE, duration?:  number, progress?:  number, from_bmp?:  ALLEGRO_BITMAP, to_bmp?:  ALLEGRO_BITMAP): TRANSITION
local TRANSITION = common.class({
    __name = "TRANSITION",

    ---@param self TRANSITION
    ---@param from? GAMESTATE
    ---@param to? GAMESTATE
    ---@param duration? number
    ---@param progress? number
    ---@param from_bmp? ALLEGRO_BITMAP
    ---@param to_bmp? ALLEGRO_BITMAP
    __init__ = function(self, from, to, duration, progress, from_bmp, to_bmp)
        if duration == nil then duration = 0 end
        if progress == nil then progress = 0 end
        self.from = from
        self.to = to
        self.duration = duration
        self.progress = progress
        self.from_bmp = from_bmp
        self.to_bmp = to_bmp
    end
})
exports.TRANSITION = TRANSITION


--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/transition.c
--]]

---@param from GAMESTATE?
---@param to GAMESTATE?
---@param duration number
---@return TRANSITION
local function create_transition(from, to, duration)
    local t = TRANSITION()

    t.from = from
    t.to = to
    t.duration = duration
    t.progress = 0.0

    t.from_bmp = allegro5.al_create_bitmap(_global.screen_width, _global.screen_height)
    allegro5.al_set_target_bitmap(t.from_bmp)
    if from then
        from.draw()
    else
        allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))
    end
    allegro5.al_set_target_backbuffer(_global.screen)

    t.to_bmp = allegro5.al_create_bitmap(_global.screen_width, _global.screen_height)
    allegro5.al_set_target_bitmap(t.to_bmp)

    if to then
        to.draw()
    else
        allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))
    end
    allegro5.al_set_target_backbuffer(_global.screen)

    return t
end
exports.create_transition = create_transition


---@param t TRANSITION
local function destroy_transition(t)
    if t.from_bmp then
        allegro5.al_destroy_bitmap(t.from_bmp)
        t.from_bmp = nil
    end

    if t.to_bmp then
        allegro5.al_destroy_bitmap(t.to_bmp)
        t.from_bmp = nil
    end
end
exports.destroy_transition = destroy_transition


---@param t TRANSITION
---@return integer
local function update_transition(t)
    t.progress = t.progress + (1.0 / _global.logic_framerate)

    if t.progress >= t.duration then
        return 0
    else
        return 1
    end
end
exports.update_transition = update_transition


---@param t TRANSITION
local function draw_transition(t)
    local y = math.floor(t.progress * _global.screen_height / t.duration)

    allegro5.al_draw_bitmap_region(t.to_bmp, 0, _global.screen_height - y, _global.screen_width, y, 0, 0, 0)
    allegro5.al_draw_bitmap_region(t.from_bmp, 0, 0, _global.screen_width, _global.screen_height - y, 0, y, 0)
end
exports.draw_transition = draw_transition

return exports
