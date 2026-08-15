local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/speed/message.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local a4_aux = require("a4_aux")

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local makecol = a4_aux.makecol
local textout_centre = a4_aux.textout_centre

--[[
 -    SPEED - by Shawn Hargreaves, 1999
 -
 -    Text message displaying functions.
 --]]



---@class MESSAGE
---@field text string
---@field time integer
---@field x number
---@field y number
---@field next? MESSAGE
---@overload fun(text? : string, time? : integer, x? : number, y? : number, next? : MESSAGE): MESSAGE
local MESSAGE = common.class({
    __name = "MESSAGE",

    ---@param self MESSAGE
    ---@param text? string
    ---@param time? integer
    ---@param x? number
    ---@param y? number
    ---@param next? MESSAGE
    __init__ = function(self, text, time, x, y, next)
        if text == nil then text = "" end
        if time == nil then time = 0 end
        if x == nil then x = 0 end
        if y == nil then y = 0 end
        self.text = text
        self.time = time
        self.x = x
        self.y = y
        self.next = next
    end
})


local msg ---@type MESSAGE?



--[[ initialises the message functions --]]
local function init_message()
    msg = nil
end
exports.init_message = init_message



--[[ closes down the message module --]]
local function shutdown_message()
    local m ---@type MESSAGE

    while msg do
        m = msg
        msg = msg.next
        -- free(m)
        m.next = nil
    end
end
exports.shutdown_message = shutdown_message



--[[ adds a new message to the display --]]
---@param text string
local function message(text)
    local m = MESSAGE()

    m.text = text

    m.time = 0

    m.x = 0
    m.y = 0

    m.next = msg
    msg = m
end
exports.message = message



---@param value MESSAGE
local function message_setter(value)
    msg = value
end

---@param self MESSAGE
---@return fun(value : MESSAGE)
local function next_setter(self)
    ---@param value MESSAGE
    return function(value)
        self.next = value
    end
end

--[[ updates the message position --]]
local function update_message()
    local SCREEN_W = allegro5.al_get_display_width(a4_aux.screen)
    local SCREEN_H = allegro5.al_get_display_height(a4_aux.screen)
    local p = message_setter ---@type fun(value : MESSAGE)
    local m = msg ---@type MESSAGE?
    local tmp ---@type MESSAGE?
    local y = math.floor(SCREEN_H / 2) ---@type integer

    while m do
        if m.time < 100 then
            m.x = m.x * (0.9)
            m.x = m.x + (SCREEN_W * 0.05)
        else
            m.x = m.x + ((m.time - 100))
        end

        m.y = m.y * (0.9)
        m.y = m.y + (y * 0.1)

        m.time = m.time + 1

        if m.x > SCREEN_W + #m.text / 4 then
            p(m.next)
            tmp = m
            m = m.next
            -- free(tmp)
            tmp.next = nil
        else
            p = next_setter(m)
            m = m.next
        end

        y = y + (16) ---@type integer
    end
end
exports.update_message = update_message



--[[ draws messages --]]
local function draw_message()
    local m = msg ---@type MESSAGE?

    while m do
        textout_centre(a4_aux.font_video, m.text, math.floor(m.x), math.floor(m.y), makecol(255, 255, 255))
        m = m.next ---@type MESSAGE?
    end
end
exports.draw_message = draw_message

return exports
