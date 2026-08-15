local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/UFO.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local logic = require("logic")
local sound = require("sound")
local Entity = require("Entity").Entity
local LargeSlowBullet = require("LargeSlowBullet").LargeSlowBullet
local Resource = require("Resource")
local ResourceManager = require("ResourceManager").ResourceManager

local new_entities = logic.new_entities

local my_play_sample = sound.my_play_sample

local RES_COLLISION = Resource.RES_COLLISION
local RES_FIRELARGE = Resource.RES_FIRELARGE
local RES_PLAYER = Resource.RES_PLAYER
local RES_UFO0 = Resource.RES_UFO0
local RES_UFO1 = Resource.RES_UFO1
local RES_UFO2 = Resource.RES_UFO2

local atan2 = math.atan2 or math.atan ---@diagnostic disable-line: deprecated

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

---@class UFO : Entity
---@field protected bitmaps ALLEGRO_BITMAP[]
---@field protected nextShot integer
---@field protected bitmapFrame integer
---@field protected bitmapFrameCount integer
---@field protected speed_x number
---@field protected speed_y number
---@overload fun(x : number, y : number, speed_x : number, speed_y : number): UFO
local UFO = common.class({
    __name = "UFO",
}, Entity)
exports.UFO = UFO

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/UFO.cpp
--]]

local SHOT_SPEED = 3000 ---@type integer
local ANIMATION_SPEED = 150 ---@type integer

---@param self UFO
---@param step integer
---@return boolean
function UFO.logic(self, step)
    local p = self:getPlayerCollision()
    if p then
        self:explode()
        p:hit(1)
        p:die()
        my_play_sample(RES_COLLISION)
        return false
    end

    local now = math.floor(allegro5.al_get_time() * 1000.0)
    if now > self.nextShot then
        self.nextShot = now + SHOT_SPEED
        local rm = ResourceManager.getInstance()
        p = rm:getData(RES_PLAYER) ---@type Player
        local px = p:getX()
        local py = p:getY()
        local shot_angle = atan2(py - self.y, px - self.x)
        local b = LargeSlowBullet(self.x, self.y, shot_angle, self)
        new_entities[#new_entities + 1] = b
        my_play_sample(RES_FIRELARGE)
    end

    self.bitmapFrameCount = self.bitmapFrameCount - (step)
    if self.bitmapFrameCount <= 0 then
        self.bitmapFrameCount = ANIMATION_SPEED
        self.bitmapFrame = self.bitmapFrame + 1
        self.bitmapFrame = self.bitmapFrame % (3); -- loop
    end

    self.dx = self.speed_x * step
    self.dy = self.speed_y * step

    Entity.wrap(self)

    if not Entity.logic(self, step) then
        return false
    end

    return true
end

---@param self UFO
---@param offx integer
---@param offy integer
function UFO.render_at(self, offx, offy)
    self:render_color_at(offx, offy, allegro5.al_map_rgb(255, 255, 255))
end

---@param self UFO
---@param offx integer
---@param offy integer
---@param tint ALLEGRO_COLOR
function UFO.render_color_at(self, offx, offy, tint)
    allegro5.al_draw_tinted_rotated_bitmap(self.bitmaps[self.bitmapFrame + INDEX_BASE], tint,
        self.radius, self.radius, offx + self.x, offy + self.y, 0.0, 0)
end

---@param self UFO
---@param x number
---@param y number
---@param speed_x number
---@param speed_y number
function UFO.UFO(self, x, y, speed_x, speed_y)
    Entity.Entity(self)

    self.bitmaps = {}

    self.x = x
    self.y = y
    self.speed_x = speed_x
    self.speed_y = speed_y

    self.radius = 32
    self.hp = 8
    self.points = 500
    self.ufo = true

    self.nextShot = math.floor(allegro5.al_get_time() * 1000.0) + SHOT_SPEED

    local rm = ResourceManager.getInstance()
    self.bitmaps[0 + INDEX_BASE] = rm:getData(RES_UFO0) ---@type ALLEGRO_BITMAP
    self.bitmaps[1 + INDEX_BASE] = rm:getData(RES_UFO1) ---@type ALLEGRO_BITMAP
    self.bitmaps[2 + INDEX_BASE] = rm:getData(RES_UFO2) ---@type ALLEGRO_BITMAP
    self.bitmapFrame = 0
    self.bitmapFrameCount = ANIMATION_SPEED
end

---@param self UFO
function UFO.__destroy(self)
end

return exports
