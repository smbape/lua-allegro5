local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/mouse.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")

local new_table = common.new_table

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/mouse.c
--]]


--[[
 - bit 0: key is down
 - bit 1: key was pressed
 - bit 2: key was released
 --]]
local MOUSE_BUTTONS = 10 ---@type integer
local mouse_array = new_table(0, MOUSE_BUTTONS)
local mx, my = 0, 0 ---@type integer

---@param b integer
---@return boolean
local function mouse_button_down(b)
    return bit.band(mouse_array[b + INDEX_BASE], 1) ~= 0
end
exports.mouse_button_down = mouse_button_down

---@param b integer
---@return boolean
local function mouse_button_pressed(b)
    return bit.band(mouse_array[b + INDEX_BASE], 2) ~= 0
end
exports.mouse_button_pressed = mouse_button_pressed

local function mouse_x()
    return mx
end
exports.mouse_x = mouse_x

local function mouse_y()
    return my
end
exports.mouse_y = mouse_y

---@param event ALLEGRO_EVENT
local function mouse_handle_event(event)
    if event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
        mouse_array[event.mouse.button + INDEX_BASE] = bit.bor(mouse_array[event.mouse.button + INDEX_BASE], bit.lshift(1, 0))
        mouse_array[event.mouse.button + INDEX_BASE] = bit.bor(mouse_array[event.mouse.button + INDEX_BASE], bit.lshift(1, 1))
    elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_UP then
        mouse_array[event.mouse.button + INDEX_BASE] = bit.band(mouse_array[event.mouse.button + INDEX_BASE], bit.bnot(bit.lshift(1, 0)))
        mouse_array[event.mouse.button + INDEX_BASE] = bit.bor(mouse_array[event.mouse.button + INDEX_BASE], bit.lshift(1, 2))
    elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_AXES then
        mx = event.mouse.x
        my = event.mouse.y
    end
end
exports.mouse_handle_event = mouse_handle_event

local function mouse_tick()
    --[[ clear pressed/released bits --]]
    for i = 1, MOUSE_BUTTONS do
        mouse_array[i] = bit.band(mouse_array[i], bit.bnot(bit.lshift(1, 1)))
        mouse_array[i] = bit.band(mouse_array[i], bit.bnot(bit.lshift(1, 2)))
    end
end
exports.mouse_tick = mouse_tick

return exports
