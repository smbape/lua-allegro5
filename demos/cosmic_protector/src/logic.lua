---@class logic
---@field lastUFO integer
---@field canUFO boolean
local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/logic.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local cosmic_protector = require("cosmic_protector")
local Game = require("Game")
local Resource = require("Resource")
local ResourceManager = require("ResourceManager").ResourceManager

local UFO ---@class UFO
exports.init = function()
    UFO = require("UFO").UFO ---@diagnostic disable-line: cast-local-type
end

local rand = common.rand

local switch_game_in = cosmic_protector.switch_game_in
local switch_game_out = cosmic_protector.switch_game_out

local randf = Game.randf

local RES_DISPLAY = Resource.RES_DISPLAY
local RES_FPS = Resource.RES_FPS
local RES_INPUT = Resource.RES_INPUT
local RES_PLAYER = Resource.RES_PLAYER

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local entities = {} ---@type Entity[]
local new_entities = {} ---@type Entity[]
-- local lastUFO = 0
-- local canUFO = false

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/logic.cpp
--]]

exports.entities = entities
exports.new_entities = new_entities

local lastUFO = -1 ---@type integer
local canUFO = true ---@type boolean
local MIN_UFO_TIME = 10000
local MAX_UFO_TIME = 50000

---@param step integer
---@return boolean
local function logic(step)
    local now = math.floor(allegro5.al_get_time() * 1000.0)

    if lastUFO < 0 then
        lastUFO = now
    end

    if canUFO and (now > (lastUFO + MIN_UFO_TIME)) then
        local r = rand() % (MAX_UFO_TIME - MIN_UFO_TIME)
        if r <= step or (now > (lastUFO + MAX_UFO_TIME)) then
            canUFO = false
            local x, y, dx, dy = 0, 0, 0, 0
            if rand() % 2 ~= 0 then
                x = -32
                y = randf(32.0, 75.0)
                dx = 0.1
                dy = 0.0
            else
                x = cosmic_protector.BB_W + 32
                y = randf(cosmic_protector.BB_H - 75, cosmic_protector.BB_H - 32)
                dx = -0.1
                dy = 0.0
            end
            local ufo = UFO(x, y, dx, dy)
            entities[#entities + 1] = ufo
        end
    end

    local rm = ResourceManager.getInstance()

    local player = rm:getData(RES_PLAYER) ---@type Player

    local input = rm:getData(RES_INPUT) ---@type Input
    input:poll()

    if input:esc() then
        return false
    end

    --[[ Catch close button presses --]]
    local events = (rm:getResource(RES_DISPLAY) --[[ @as DisplayResource --]]):getEventQueue()
    while not allegro5.al_is_event_queue_empty(events) do
        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_get_next_event(events, event)
        if allegro5.ALLEGRO_IPHONE then
            if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_HALT_DRAWING or event.type == allegro5.ALLEGRO_EVENT_DISPLAY_SWITCH_OUT then
                switch_game_out(event.type == allegro5.ALLEGRO_EVENT_DISPLAY_HALT_DRAWING)
            elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESUME_DRAWING or event.type == allegro5.ALLEGRO_EVENT_DISPLAY_SWITCH_IN then
                switch_game_in()
            end
        else
            if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
                os.exit(0)
            end
        end
    end

    local j = 1
    for i = 1, #entities do
        local e = entities[i]
        if not e:logic(step) then
            if e:isUFO() then
                lastUFO = now
                canUFO = true
            end
            e:__destroy()
        else
            entities[j] = e
            j = j + 1
        end
    end

    for i = j, #entities do
        entities[i] = nil
    end

    for _, e in ipairs(new_entities) do
        entities[#entities + 1] = e
    end
    for i = 1, #new_entities do
        new_entities[i] = nil
    end

    if not player:logic(step) then
        return false
    end

    local fps = rm:getData(RES_FPS) ---@type FPS
    fps:frame()

    return true
end
exports.logic = logic

local getters = {
    lastUFO = function() return lastUFO end,
    canUFO = function() return canUFO end,
}

local setters = {
    lastUFO = function(value) lastUFO = value end,
    canUFO = function(value) canUFO = value end,
}

setmetatable(exports, {
    __index = function(self, key)
        local getter = getters[key]
        if type(getter) == "function" then
            return getter()
        end
        return nil
    end,
    __newindex = function(self, key, value)
        local setter = setters[key]
        if type(setter) == "function" then
            setter(value)
        else
            rawset(self, key, value)
        end
    end
})

return exports
