local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/Resource.hpp
--]]

local common = require("examples.common")

local RES_DISPLAY = 0; exports.RES_DISPLAY = RES_DISPLAY
local RES_PLAYER = 1; exports.RES_PLAYER = RES_PLAYER
local RES_INPUT = 2; exports.RES_INPUT = RES_INPUT
local RES_LARGEFONT = 3; exports.RES_LARGEFONT = RES_LARGEFONT
local RES_SMALLFONT = 4; exports.RES_SMALLFONT = RES_SMALLFONT

local RES_BITMAP_START = 5; exports.RES_BITMAP_START = RES_BITMAP_START
local RES_LARGEASTEROID = RES_BITMAP_START + 0; exports.RES_LARGEASTEROID = RES_LARGEASTEROID
local RES_SMALLASTEROID = RES_BITMAP_START + 1; exports.RES_SMALLASTEROID = RES_SMALLASTEROID
local RES_BACKGROUND = RES_BITMAP_START + 2; exports.RES_BACKGROUND = RES_BACKGROUND
local RES_SMALLBULLET = RES_BITMAP_START + 3; exports.RES_SMALLBULLET = RES_SMALLBULLET
local RES_LARGEEXPLOSION0 = RES_BITMAP_START + 4; exports.RES_LARGEEXPLOSION0 = RES_LARGEEXPLOSION0
local RES_LARGEEXPLOSION1 = RES_BITMAP_START + 5; exports.RES_LARGEEXPLOSION1 = RES_LARGEEXPLOSION1
local RES_LARGEEXPLOSION2 = RES_BITMAP_START + 6; exports.RES_LARGEEXPLOSION2 = RES_LARGEEXPLOSION2
local RES_LARGEEXPLOSION3 = RES_BITMAP_START + 7; exports.RES_LARGEEXPLOSION3 = RES_LARGEEXPLOSION3
local RES_LARGEEXPLOSION4 = RES_BITMAP_START + 8; exports.RES_LARGEEXPLOSION4 = RES_LARGEEXPLOSION4
local RES_SMALLEXPLOSION0 = RES_BITMAP_START + 9; exports.RES_SMALLEXPLOSION0 = RES_SMALLEXPLOSION0
local RES_SMALLEXPLOSION1 = RES_BITMAP_START + 10; exports.RES_SMALLEXPLOSION1 = RES_SMALLEXPLOSION1
local RES_SMALLEXPLOSION2 = RES_BITMAP_START + 11; exports.RES_SMALLEXPLOSION2 = RES_SMALLEXPLOSION2
local RES_SMALLEXPLOSION3 = RES_BITMAP_START + 12; exports.RES_SMALLEXPLOSION3 = RES_SMALLEXPLOSION3
local RES_SMALLEXPLOSION4 = RES_BITMAP_START + 13; exports.RES_SMALLEXPLOSION4 = RES_SMALLEXPLOSION4
local RES_MEDIUMASTEROID = RES_BITMAP_START + 14; exports.RES_MEDIUMASTEROID = RES_MEDIUMASTEROID
local RES_LARGEBULLET = RES_BITMAP_START + 15; exports.RES_LARGEBULLET = RES_LARGEBULLET
local RES_WEAPONPOWERUP = RES_BITMAP_START + 16; exports.RES_WEAPONPOWERUP = RES_WEAPONPOWERUP
local RES_LIFEPOWERUP = RES_BITMAP_START + 17; exports.RES_LIFEPOWERUP = RES_LIFEPOWERUP
local RES_UFO0 = RES_BITMAP_START + 18; exports.RES_UFO0 = RES_UFO0
local RES_UFO1 = RES_BITMAP_START + 19; exports.RES_UFO1 = RES_UFO1
local RES_UFO2 = RES_BITMAP_START + 20; exports.RES_UFO2 = RES_UFO2
local RES_LOGO = RES_BITMAP_START + 21; exports.RES_LOGO = RES_LOGO

local RES_SAMPLE_START = RES_BITMAP_START + 22; exports.RES_SAMPLE_START = RES_SAMPLE_START
local RES_BIGEXPLOSION = RES_SAMPLE_START + 0; exports.RES_BIGEXPLOSION = RES_BIGEXPLOSION
local RES_COLLISION = RES_SAMPLE_START + 1; exports.RES_COLLISION = RES_COLLISION
local RES_FIRELARGE = RES_SAMPLE_START + 2; exports.RES_FIRELARGE = RES_FIRELARGE
local RES_FIRESMALL = RES_SAMPLE_START + 3; exports.RES_FIRESMALL = RES_FIRESMALL
local RES_SMALLEXPLOSION = RES_SAMPLE_START + 4; exports.RES_SMALLEXPLOSION = RES_SMALLEXPLOSION
local RES_POWERUP = RES_SAMPLE_START + 5; exports.RES_POWERUP = RES_POWERUP
local RES_SAMPLE_END = RES_POWERUP + 1; exports.RES_SAMPLE_END = RES_SAMPLE_END

local RES_STREAM_START = RES_SAMPLE_START + 6; exports.RES_STREAM_START = RES_STREAM_START
local RES_TITLE_MUSIC = RES_STREAM_START + 0; exports.RES_TITLE_MUSIC = RES_TITLE_MUSIC
local RES_GAME_MUSIC = RES_STREAM_START + 1; exports.RES_GAME_MUSIC = RES_GAME_MUSIC
local RES_STREAM_END = RES_GAME_MUSIC + 1; exports.RES_STREAM_END = RES_STREAM_END

local RES_FPS = RES_GAME_MUSIC + 1; exports.RES_FPS = RES_FPS

-- extern const char* BMP_NAMES[]
-- extern const char* SAMPLE_NAMES[]
-- extern const char* STREAM_NAMES[]

---@class Resource
---@overload fun(): Resource
local Resource = common.class({
    __name = "Resource",
})
exports.Resource = Resource

---@param self Resource
function Resource.__destroy(self)
end

---@param self Resource
function Resource.destroy(self)
    error("Implentation needed")
end

---@param self Resource
---@return boolean
function Resource.load(self)
    error("Implentation needed")
end

---@param self Resource
---@return any
function Resource.get(self)
    error("Implentation needed")
end

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/Resource.cpp
--]]

local BMP_NAMES = {
    "gfx/large_asteroid.png",
    "gfx/small_asteroid.png",
    "gfx/background.jpg",
    "gfx/small_bullet.png",
    "gfx/large_explosion_0.png",
    "gfx/large_explosion_1.png",
    "gfx/large_explosion_2.png",
    "gfx/large_explosion_3.png",
    "gfx/large_explosion_4.png",
    "gfx/small_explosion_0.png",
    "gfx/small_explosion_1.png",
    "gfx/small_explosion_2.png",
    "gfx/small_explosion_3.png",
    "gfx/small_explosion_4.png",
    "gfx/medium_asteroid.png",
    "gfx/large_bullet.png",
    "gfx/weapon_powerup.png",
    "gfx/life_powerup.png",
    "gfx/ufo0.png",
    "gfx/ufo1.png",
    "gfx/ufo2.png",
    "gfx/logo.png",
    -- 0
}
exports.BMP_NAMES = BMP_NAMES

local SAMPLE_NAMES = {
    "sfx/big_explosion.ogg",
    "sfx/collision.ogg",
    "sfx/fire_large.ogg",
    "sfx/fire_small.ogg",
    "sfx/small_explosion.ogg",
    "sfx/powerup.ogg",
    -- 0
}
exports.SAMPLE_NAMES = SAMPLE_NAMES

local STREAM_NAMES = {
    "sfx/title_music.ogg",
    "sfx/game_music.ogg",
    -- 0
}
exports.STREAM_NAMES = STREAM_NAMES

return exports
