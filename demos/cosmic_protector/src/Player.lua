local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/Player.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local cosmic_protector = require("cosmic_protector")
local logic = require("logic")
local render = require("render")
local sound = require("sound")
local Debug = require("Debug")
local Entity = require("Entity").Entity
local Game = require("Game")
local LargeBullet = require("LargeBullet").LargeBullet
local PowerUp = require("PowerUp")
local Resource = require("Resource")
local ResourceManager = require("ResourceManager").ResourceManager
local SmallBullet = require("SmallBullet").SmallBullet
local Weapon = require("Weapon")

local INT_MAX = allegro5_lua.C.INT_MAX

local entities = logic.entities
local new_entities = logic.new_entities

local shake = render.shake

local my_play_sample = sound.my_play_sample

local debug_message = Debug.debug_message

local getResource = Game.getResource

local RES_FIRELARGE = Resource.RES_FIRELARGE
local RES_FIRESMALL = Resource.RES_FIRESMALL
local RES_FPS = Resource.RES_FPS
local RES_INPUT = Resource.RES_INPUT
local RES_LARGEFONT = Resource.RES_LARGEFONT
local RES_SMALLFONT = Resource.RES_SMALLFONT

local POWERUP_LIFE = PowerUp.POWERUP_LIFE
local POWERUP_WEAPON = PowerUp.POWERUP_WEAPON

local WEAPON_LARGE = Weapon.WEAPON_LARGE
local WEAPON_SMALL = Weapon.WEAPON_SMALL

local cos = math.cos
local sin = math.sin

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

---@class Player : Entity, Resource
---@field private angle number
---@field private draw_radius number
---@field private draw_trail boolean
---@field private weapon integer
---@field private lastShot integer
---@field private lives integer
---@field private invincibleCount integer
---@field private score integer
---@field private bitmap? ALLEGRO_BITMAP
---@field private trans_bitmap? ALLEGRO_BITMAP
---@field private trail_bitmap? ALLEGRO_BITMAP
---@field private icon? ALLEGRO_BITMAP
---@field private highscoreBitmap? ALLEGRO_BITMAP
---@overload fun(): Player
local Player = common.class({
    __name = "Player",
}, Entity, Resource.Resource)
exports.Player = Player

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/Player.cpp
--]]

local MAX_SPEED = 10.0 ---@type number
local MIN_SPEED = -10.0 ---@type number
local ACCEL = 0.006 ---@type number
local DECCEL = 0.001 ---@type number

---@param self Player
---@param step integer
---@return boolean
function Player.logic(self, step)
    if not self.isDestructable and self.invincibleCount > 0 then
        self.invincibleCount = self.invincibleCount - (step)
        if self.invincibleCount <= 0 then
            self.isDestructable = true
            if self.lives <= 0 then
                return false
            end
        end
    end

    if self.lives <= 0 then
        return true
    end

    local rm = ResourceManager.getInstance()
    local input = rm:getData(RES_INPUT) ---@type Input

    if input:lr() < 0.0 then
        self.angle = self.angle - (0.005 * step)
    elseif input:lr() > 0.0 then
        self.angle = self.angle + (0.005 * step)
    end

    if input:ud() < 0.0 then
        self.dx = self.dx + (ACCEL * step * cos(self.angle))
        if self.dx > MAX_SPEED then
            self.dx = MAX_SPEED
        elseif self.dx < MIN_SPEED then
            self.dx = MIN_SPEED
        end
        self.dy = self.dy + (ACCEL * step * sin(self.angle))
        if self.dy > MAX_SPEED then
            self.dy = MAX_SPEED
        elseif self.dy < MIN_SPEED then
            self.dy = MIN_SPEED
        end
        self.draw_trail = true
    elseif input:ud() > 0.0 then
        if self.dx > 0 then
            self.dx = self.dx - (ACCEL * step)
        elseif self.dx < 0 then
            self.dx = self.dx + (ACCEL * step)
        end
        if self.dx > -0.1 and self.dx < 0.1 then
            self.dx = 0
        end
        if self.dy > 0 then
            self.dy = self.dy - (ACCEL * step)
        elseif self.dy < 0 then
            self.dy = self.dy + (ACCEL * step)
        end
        if self.dy > -0.1 and self.dy < 0.1 then
            self.dy = 0
        end
        self.draw_trail = false
    else
        if self.dx > 0 then
            self.dx = self.dx - (DECCEL * step)
        elseif self.dx < 0 then
            self.dx = self.dx + (DECCEL * step)
        end
        if self.dx > -0.1 and self.dx < 0.1 then
            self.dx = 0
        end
        if self.dy > 0 then
            self.dy = self.dy - (DECCEL * step)
        elseif self.dy < 0 then
            self.dy = self.dy + (DECCEL * step)
        end
        if self.dy > -0.1 and self.dy < 0.1 then
            self.dy = 0
        end
        self.draw_trail = false
    end

    local shotRate = 0

    if self.weapon == WEAPON_SMALL then
        shotRate = 300
    elseif self.weapon == WEAPON_LARGE then
        shotRate = 250
    else
        shotRate = INT_MAX
    end

    local now = math.floor(allegro5.al_get_time() * 1000.0)
    if (self.lastShot + shotRate) < now and input:b1() then
        self.lastShot = now
        local realAngle = self.angle
        local bx = self.x + self.radius * cos(realAngle)
        local by = self.y + self.radius * sin(realAngle)
        local b ---@type Bullet?
        local resourceID = RES_FIRESMALL

        if self.weapon == WEAPON_SMALL then
            b = SmallBullet(bx, by, self.angle, self)
            resourceID = RES_FIRESMALL
        elseif self.weapon == WEAPON_LARGE then
            b = LargeBullet(bx, by, self.angle, self)
            resourceID = RES_FIRELARGE
        end
        if b then
            my_play_sample(resourceID)
            new_entities[#new_entities + 1] = b
        end
    end

    if input:cheat() then
        allegro5.al_rest(0.250)
        for _, e in ipairs(entities) do
            e:__destroy()
        end
        for i = 1, #entities do
            entities[i] = nil
        end
    end

    Entity.wrap(self)

    if not Entity.logic(self, step) then
        return false
    end

    return true
end

---@param self Player
function Player.render_extra(self)
    local rm = ResourceManager.getInstance()

    if self.lives <= 0 then
        local w = allegro5.al_get_bitmap_width(self.highscoreBitmap)
        local h = allegro5.al_get_bitmap_height(self.highscoreBitmap)
        allegro5.al_draw_bitmap(self.highscoreBitmap, math.floor((cosmic_protector.BB_W - w) / 2), math.floor((cosmic_protector.BB_H - h) / 2), 0)
        return
    end

    local st = allegro5.ALLEGRO_STATE()
    allegro5.al_store_state(st, allegro5.ALLEGRO_STATE_BLENDER)
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
    allegro5.al_draw_bitmap(self.icon, 1, 2, 0)
    allegro5.al_restore_state(st)
    local small_font = rm:getData(RES_SMALLFONT) ---@type allegro5.ALLEGRO_FONT
    allegro5.al_draw_text(small_font, allegro5.al_map_rgb(255, 255, 255), 20, 2, 0, string.format("x%d", self.lives))
    allegro5.al_draw_text(small_font, allegro5.al_map_rgb(255, 255, 255), 2, 18, 0, string.format("%d", self.score))

    local fps = rm:getData(RES_FPS) ---@type FPS
    allegro5.al_draw_text(small_font, allegro5.al_map_rgb(255, 255, 255), 2, 34, 0, string.format("FPS : %.3f", fps:compute()))
end

---@param self Player
---@param offx integer
---@param offy integer
---@param tint allegro5.ALLEGRO_COLOR
function Player.render_color_at(self, offx, offy, tint)
    if self.lives <= 0 then
        return
    end

    local rx, ry = math.floor(offx + self.x), math.floor(offy + self.y)

    if not self.isDestructable then
        allegro5.al_draw_tinted_rotated_bitmap(self.trans_bitmap, tint,
            self.draw_radius, self.draw_radius, rx, ry,
            self.angle + (allegro5.ALLEGRO_PI / 2.0), 0)
    else
        allegro5.al_draw_tinted_rotated_bitmap(self.bitmap,
            tint, self.draw_radius, self.draw_radius, rx, ry,
            self.angle + (allegro5.ALLEGRO_PI / 2.0), 0)
    end
    if self.draw_trail then
        local tw = allegro5.al_get_bitmap_width(self.trail_bitmap)
        local th = allegro5.al_get_bitmap_height(self.trail_bitmap)
        local ca = (allegro5.ALLEGRO_PI * 2) + self.angle
        local a = ca + ((210.0 / 180.0) * allegro5.ALLEGRO_PI)
        local tx = rx + 42.0 * cos(a)
        local ty = ry + 42.0 * sin(a)
        allegro5.al_draw_tinted_rotated_bitmap(self.trail_bitmap, tint, tw, math.floor(th / 2),
            tx, ty, a, 0)
        a = ca + ((150.0 / 180.0) * allegro5.ALLEGRO_PI)
        tx = rx + 42.0 * cos(a)
        ty = ry + 42.0 * sin(a)
        allegro5.al_draw_tinted_rotated_bitmap(self.trail_bitmap, tint, tw, math.floor(th / 2),
            tx, ty, a, 0)
    end
end

---@param self Player
---@param offx any
---@param offy any
function Player.render_at(self, offx, offy)
    self:render_color_at(offx, offy, allegro5.al_map_rgb(255, 255, 255))
end

---@param self Player
---@param damage integer
---@return boolean
function Player.hit(self, damage)
    Entity.hit(self, damage)
    self:die()
    return true
end

---@param self Player
function Player.Player(self)
    Entity.Entity(self)

    self.angle = 0.0
    self.draw_radius = 0.0
    self.draw_trail = false
    self.lives = 0
    self.invincibleCount = 0

    self.weapon = WEAPON_SMALL
    self.lastShot = 0
    self.score = 0
    self.bitmap = nil
    self.trans_bitmap = nil
    self.trail_bitmap = nil
    self.icon = nil
    self.highscoreBitmap = nil
end

---@param self Player
function Player.__destroy(self)
end

---@param self Player
function Player.destroy(self)
    allegro5.al_destroy_bitmap(self.bitmap)
    allegro5.al_destroy_bitmap(self.trans_bitmap)
    allegro5.al_destroy_bitmap(self.trail_bitmap)
    allegro5.al_destroy_bitmap(self.icon)
    allegro5.al_destroy_bitmap(self.highscoreBitmap)
    self.bitmap = nil
    self.trans_bitmap = nil
    self.trail_bitmap = nil
    self.icon = nil
    self.highscoreBitmap = nil
end

---@param self Player
---@return boolean
function Player.load(self)
    local state = allegro5.ALLEGRO_STATE()
    allegro5.al_store_state(state, bit.bor(allegro5.ALLEGRO_STATE_TARGET_BITMAP, allegro5.ALLEGRO_STATE_BLENDER))

    self.bitmap = allegro5.al_load_bitmap(getResource("gfx/ship.png"))
    if not self.bitmap then
        debug_message("Error loading %s\n", getResource("gfx/ship.png"))
        return false
    end

    self.trans_bitmap = allegro5.al_create_bitmap(allegro5.al_get_bitmap_width(self.bitmap),
        allegro5.al_get_bitmap_height(self.bitmap))
    if not self.trans_bitmap then
        debug_message("Error loading %s\n", getResource("gfx/ship_trans.png"))
        allegro5.al_destroy_bitmap(self.bitmap)
        return false
    end

    --[[ Make a translucent copy of the ship --]]
    allegro5.al_set_target_bitmap(self.trans_bitmap)
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
    allegro5.al_draw_tinted_bitmap(self.bitmap, allegro5.al_map_rgba(255, 255, 255, 160),
        0, 0, 0)
    allegro5.al_restore_state(state)

    self.trail_bitmap = allegro5.al_load_bitmap(getResource("gfx/trail.png"))
    if not self.trail_bitmap then
        debug_message("Error loading %s\n", getResource("gfx/trail.png"))
        allegro5.al_destroy_bitmap(self.bitmap)
        allegro5.al_destroy_bitmap(self.trans_bitmap)
        return false
    end

    self.icon = allegro5.al_load_bitmap(getResource("gfx/ship_icon.tga"))
    if not self.icon then
        debug_message("Error loading %s\n", getResource("gfx/ship_icon.tga"))
        allegro5.al_destroy_bitmap(self.bitmap)
        allegro5.al_destroy_bitmap(self.trans_bitmap)
        allegro5.al_destroy_bitmap(self.trail_bitmap)
        return false
    end

    self.highscoreBitmap = allegro5.al_create_bitmap(300, 200)
    allegro5.al_set_target_bitmap(self.highscoreBitmap)
    allegro5.al_clear_to_color(allegro5.al_map_rgba(0, 0, 0, 0))

    allegro5.al_restore_state(state)

    self.draw_radius = math.floor(allegro5.al_get_bitmap_width(self.bitmap) / 2)
    self.radius = self.draw_radius / 2

    self:newGame()
    self:reset()

    return true
end

---@param self Player
---@return Player
function Player.get(self)
    return self
end

---@param self Player
function Player.newGame(self)
    self.lives = 5
    self.hp = 1
    self.score = 0
    self.isDestructable = true
end

---@param self Player
function Player.reset(self)
    self.x = math.floor(cosmic_protector.BB_W / 2)
    self.y = math.floor(cosmic_protector.BB_H / 2)
    self.dx = 0
    self.dy = 0
    self.angle = -allegro5.ALLEGRO_PI / 2
    self.draw_trail = false
    self.weapon = WEAPON_SMALL
end

---@param self Player
function Player.die(self)
    shake()
    self:reset()

    self.lives = self.lives - 1
    if self.lives <= 0 then
        -- game over
        self.isDestructable = false
        self.invincibleCount = 8000
        local old_target = allegro5.al_get_target_bitmap()
        allegro5.al_set_target_bitmap(self.highscoreBitmap)
        local w = allegro5.al_get_bitmap_width(self.highscoreBitmap)
        local h = allegro5.al_get_bitmap_height(self.highscoreBitmap)
        local rm = ResourceManager.getInstance()
        local large_font = rm:getData(RES_LARGEFONT) ---@type allegro5.ALLEGRO_FONT
        local small_font = rm:getData(RES_SMALLFONT) ---@type allegro5.ALLEGRO_FONT
        allegro5.al_draw_text(large_font, allegro5.al_map_rgb(255, 255, 255), math.floor(w / 2), math.floor(h / 2) - 16,
            allegro5.ALLEGRO_ALIGN_CENTRE, "GAME OVER")
        allegro5.al_draw_text(small_font, allegro5.al_map_rgb(255, 255, 255), math.floor(w / 2), math.floor(h / 2) + 16,
            allegro5.ALLEGRO_ALIGN_CENTRE, string.format("%d Points", self.score))
        allegro5.al_set_target_bitmap(old_target)
    else
        self.hp = 1
        self.isDestructable = false
        self.invincibleCount = 3000
    end
end

---@param self Player
---@param _type integer
function Player.givePowerUp(self, _type)
    if _type == POWERUP_LIFE then
        self.lives = self.lives + 1
    elseif _type == POWERUP_WEAPON then
        self.weapon = WEAPON_LARGE
    end
end

---@param self Player
---@param points integer
function Player.addScore(self, points)
    self.score = self.score + (points)
end

---@param self Player
---@return integer
function Player.getScore(self)
    return self.score
end

---@param self Player
---@return number
function Player.getAngle(self)
    return self.angle
end

---@param self Player
---@return number dx
---@return number dy
function Player.getSpeed(self)
    return self.dx, self.dy
end

return exports
