---@class module_DisplayResource
---@field useFullScreenMode boolean
local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/DisplayResource.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local cosmic_protector = require("cosmic_protector")
local Game = require("Game")
local Resource = require("Resource").Resource

local getResource = Game.getResource

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

---@class DisplayResource : Resource
---@field private display? ALLEGRO_DISPLAY
---@field private events? ALLEGRO_EVENT_QUEUE
---@overload fun(): DisplayResource
local DisplayResource = common.class({
    __name = "DisplayResource",
}, Resource)
exports.DisplayResource = DisplayResource

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/DisplayResource.cpp
--]]

local useFullScreenMode = false

if allegro5.ALLEGRO_IPHONE then
    cosmic_protector.BB_W = 0
    cosmic_protector.BB_H = 0
else
    cosmic_protector.BB_W = 800
    cosmic_protector.BB_H = 600
end

---@param self DisplayResource
function DisplayResource.destroy(self)
    if not self.display then
        return
    end
    allegro5.al_destroy_event_queue(self.events)
    allegro5.al_destroy_display(self.display)
    self.display = nil
end

---@param self DisplayResource
---@return boolean
function DisplayResource.load(self)
    local flags ---@type integer
    if allegro5.ALLEGRO_IPHONE then
        flags = allegro5.ALLEGRO_FULLSCREEN_WINDOW
        allegro5.al_set_new_display_option(allegro5.ALLEGRO_SUPPORTED_ORIENTATIONS,
            allegro5.ALLEGRO_DISPLAY_ORIENTATION_LANDSCAPE, allegro5.ALLEGRO_REQUIRE)
    else
        flags = (function() if useFullScreenMode then return allegro5.ALLEGRO_FULLSCREEN else return allegro5
                .ALLEGRO_WINDOWED end end)()
    end
    allegro5.al_set_new_display_flags(flags)
    self.display = allegro5.al_create_display(cosmic_protector.BB_W, cosmic_protector.BB_H)
    if not self.display then
        return false
    end

    if not allegro5.ALLEGRO_IPHONE then
        local bmp = allegro5.al_load_bitmap(getResource("gfx/icon48.png"))
        allegro5.al_set_display_icon(self.display, bmp)
        allegro5.al_destroy_bitmap(bmp)
    end

    cosmic_protector.BB_W = allegro5.al_get_display_width(self.display)
    cosmic_protector.BB_H = allegro5.al_get_display_height(self.display)

    if allegro5.ALLEGRO_IPHONE then
        if cosmic_protector.BB_W < 960 then
            cosmic_protector.BB_W = cosmic_protector.BB_W * (2)
            cosmic_protector.BB_H = cosmic_protector.BB_H * (2)
            local t = allegro5.ALLEGRO_TRANSFORM()
            allegro5.al_identity_transform(t)
            allegro5.al_scale_transform(t, 0.5, 0.5)
            allegro5.al_use_transform(t)
        end
    end

    self.events = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(self.events, allegro5.al_get_display_event_source(self.display))

    return true
end

---@param self DisplayResource
---@return ALLEGRO_DISPLAY?
function DisplayResource.get(self)
    return self.display
end

---@param self DisplayResource
---@return ALLEGRO_EVENT_QUEUE?
function DisplayResource.getEventQueue(self)
    return self.events
end

---@param self DisplayResource
function DisplayResource.DisplayResource(self)
end

local getters = {
    useFullScreenMode = function() return useFullScreenMode end,
}

local setters = {
    useFullScreenMode = function(value) useFullScreenMode = value end,
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
