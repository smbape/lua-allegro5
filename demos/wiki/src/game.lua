#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) ..
    arg[0]:gsub("[^/\\]+%.lua", '../../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro_wiki/wiki/src/game.c
    https://github.com/liballeg/allegro_wiki/wiki/Allegro-Vivace-%E2%80%93-Gameplay
    https://github.com/liballeg/allegro_wiki/wiki/Resolution-independence
--]]

local __file__ = arg[0]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: undefined-global
local common = require("examples.common")

local RAND_MAX = common.RAND_MAX
local rand = common.rand
local printf = common.printf
local new_table = common.new_table

local INDEX_BASE = 1 -- lua is 1-based indexed
local ALLEGRO_WIKI_DATA_PATH = common.path.dirname(common.path.dirname(__file__))

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")()
end

--[[ this is a complete copy of the source from allegro vivace's 'gameplay' section.
 -
 - for gcc users, it can be compiled & run with:
 -
 - gcc game.c -o game $(pkg-config allegro-5 allegro_font-5 allegro_primitives-5 allegro_audio-5 allegro_acodec-5 allegro_image-5 --libs --cflags)
 - ./game
 --]]


-- --- general ---

local frames = 0 ---@typpe integer
local score = 0 ---@typpe integer
local desired_fps = 60 ---@type integer
local fps ---@type FPS

---@param test any
---@param description string
local function must_init(test, description)
    if test ~= nil and test ~= false and test ~= 0 then
        return
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end

    printf("couldn't initialize %s\n", description)
    os.exit(1)
end

---@param lo integer
---@param hi integer
---@return integer
local function between(lo, hi)
    return lo + (rand() % (hi - lo))
end

---@param lo number
---@param hi number
---@return number
local function between_f(lo, hi)
    return lo + (rand() / RAND_MAX) * (hi - lo)
end

---@param ax1 integer
---@param ay1 integer
---@param ax2 integer
---@param ay2 integer
---@param bx1 integer
---@param by1 integer
---@param bx2 integer
---@param by2 integer
---@return boolean
local function collide(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)
    if ax1 > bx2 then
        return false
    end
    if ax2 < bx1 then
        return false
    end
    if ay1 > by2 then
        return false
    end
    if ay2 < by1 then
        return false
    end

    return true
end


-- --- display ---
local BUFFER_W = 320
local BUFFER_H = 240

local DISP_SCALE = 3
local DISP_W = (BUFFER_W * DISP_SCALE)
local DISP_H = (BUFFER_H * DISP_SCALE)
local DISP_FLAGS = 0

local disp ---@type ALLEGRO_DISPLAY?
local buffer ---@type ALLEGRO_BITMAP?

local function disp_transform_update()
    local disp_w = allegro5.al_get_display_width(disp)
    local disp_h = allegro5.al_get_display_height(disp)

    local scale_factor_x = disp_w / DISP_W
    local scale_factor_y = disp_h / DISP_H
    local translate_factor_x = 0 ---@integer
    local translate_factor_y = 0 ---@integer

    if math.abs(scale_factor_x - scale_factor_y) > 1e-6 then
        local ratio = DISP_W / DISP_H

        if scale_factor_x > scale_factor_y then
            scale_factor_x = scale_factor_y
            translate_factor_x = math.floor((disp_w - disp_h * ratio) / 2)
        else
            scale_factor_y = scale_factor_x
            translate_factor_y = math.floor((disp_h - disp_w / ratio) / 2)
        end
    end

    local transform = allegro5.ALLEGRO_TRANSFORM()

    allegro5.al_identity_transform(transform)
    allegro5.al_scale_transform(transform, scale_factor_x, scale_factor_y)

    if translate_factor_x ~= 0 or translate_factor_y ~= 0 then
        allegro5.al_translate_transform(transform, translate_factor_x, translate_factor_y)
    end

    allegro5.al_use_transform(transform)
end

local function disp_init()
    if DISP_FLAGS ~= 0 then
        allegro5.al_set_new_display_flags(DISP_FLAGS)
    end

    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLE_BUFFERS, 1, allegro5.ALLEGRO_SUGGEST)
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLES, 8, allegro5.ALLEGRO_SUGGEST)

    disp = allegro5.al_create_display(DISP_W, DISP_H)
    must_init(disp, "display")

    printf("%s %d x %d\n", "Display", allegro5.al_get_display_width(disp), allegro5.al_get_display_height(disp))

    buffer = allegro5.al_create_bitmap(BUFFER_W, BUFFER_H)
    must_init(buffer, "bitmap buffer")

    disp_transform_update()
end

local function disp_deinit()
    allegro5.al_destroy_bitmap(buffer)
    allegro5.al_destroy_display(disp)
end

local function disp_pre_draw()
    allegro5.al_set_target_bitmap(buffer)
end

local function disp_post_draw()
    allegro5.al_set_target_backbuffer(disp)
    allegro5.al_draw_scaled_bitmap(buffer, 0, 0, BUFFER_W, BUFFER_H, 0, 0, DISP_W, DISP_H, 0)

    allegro5.al_flip_display()
end


-- --- keyboard ---

local KEY_SEEN = 1
local KEY_DOWN = 2
local key = {} ---@type integer[]

local function keyboard_init()
    key = new_table(0, allegro5.ALLEGRO_KEY_MAX)
end

local function keyboard_update(event)
    if event.type == allegro5.ALLEGRO_EVENT_TIMER then
        for i = 1, allegro5.ALLEGRO_KEY_MAX do
            key[i] = bit.band(key[i], bit.bnot(KEY_SEEN))
        end
    elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
        key[event.keyboard.keycode + INDEX_BASE] = bit.bor(KEY_SEEN, KEY_DOWN)
    elseif event.type == allegro5.ALLEGRO_EVENT_KEY_UP then
        key[event.keyboard.keycode + INDEX_BASE] = bit.band(key[event.keyboard.keycode + INDEX_BASE], bit.bnot(KEY_DOWN))
    end
end


-- --- sprites ---

local SHIP_W = 12
local SHIP_H = 13

local SHIP_SHOT_W = 2
local SHIP_SHOT_H = 9

local LIFE_W = 6
local LIFE_H = 6

local ALIEN_W = { 14, 13, 45 }
local ALIEN_H = { 9, 10, 27 }

local ALIEN_BUG_W = ALIEN_W[0 + INDEX_BASE]
local ALIEN_BUG_H = ALIEN_H[0 + INDEX_BASE]
local ALIEN_ARROW_W = ALIEN_W[1 + INDEX_BASE]
local ALIEN_ARROW_H = ALIEN_H[1 + INDEX_BASE]
local ALIEN_THICCBOI_W = ALIEN_W[2 + INDEX_BASE]
local ALIEN_THICCBOI_H = ALIEN_H[2 + INDEX_BASE]

local ALIEN_SHOT_W = 4
local ALIEN_SHOT_H = 4

local EXPLOSION_FRAMES = 4
local SPARKS_FRAMES = 3


---@class SPRITES
---@field _sheet ALLEGRO_BITMAP?
---@field ship ALLEGRO_BITMAP?
---@field ship_shot ALLEGRO_BITMAP[]
---@field life ALLEGRO_BITMAP?
---@field alien ALLEGRO_BITMAP[]
---@field alien_shot ALLEGRO_BITMAP?
---@field explosion ALLEGRO_BITMAP[]
---@field sparks ALLEGRO_BITMAP[]
---@field powerup ALLEGRO_BITMAP[]
---@overload fun(): SPRITES
local SPRITES = common.class({
    __name = "SPRITES",
})

---@param self SPRITES
function SPRITES.__init__(self)
    self.ship_shot = {}
    self.alien = {}
    self.explosion = {}
    self.sparks = {}
    self.powerup = {}
end

local sprites = SPRITES()

---@param x integer
---@param y integer
---@param w integer
---@param h integer
---@return allegro5.ALLEGRO_BITMAP|nil
local function sprite_grab(x, y, w, h)
    local sprite = allegro5.al_create_sub_bitmap(sprites._sheet, x, y, w, h)
    must_init(sprite, "sprite grab")
    return sprite
end

local function sprites_init()
    sprites._sheet = allegro5.al_load_bitmap(ALLEGRO_WIKI_DATA_PATH .. "/img/spritesheet.png")
    must_init(sprites._sheet, "spritesheet")

    sprites.ship = sprite_grab(0, 0, SHIP_W, SHIP_H)

    sprites.ship_shot[0 + INDEX_BASE] = sprite_grab(13, 0, SHIP_SHOT_W, SHIP_SHOT_H)
    sprites.ship_shot[1 + INDEX_BASE] = sprite_grab(16, 0, SHIP_SHOT_W, SHIP_SHOT_H)

    sprites.life = sprite_grab(0, 14, LIFE_W, LIFE_H)

    sprites.alien[0 + INDEX_BASE] = sprite_grab(19, 0, ALIEN_BUG_W, ALIEN_BUG_H)
    sprites.alien[1 + INDEX_BASE] = sprite_grab(19, 10, ALIEN_ARROW_W, ALIEN_ARROW_H)
    sprites.alien[2 + INDEX_BASE] = sprite_grab(0, 21, ALIEN_THICCBOI_W, ALIEN_THICCBOI_H)

    sprites.alien_shot = sprite_grab(13, 10, ALIEN_SHOT_W, ALIEN_SHOT_H)

    sprites.explosion[0 + INDEX_BASE] = sprite_grab(33, 10, 9, 9)
    sprites.explosion[1 + INDEX_BASE] = sprite_grab(43, 9, 11, 11)
    sprites.explosion[2 + INDEX_BASE] = sprite_grab(46, 21, 17, 18)
    sprites.explosion[3 + INDEX_BASE] = sprite_grab(46, 40, 17, 17)

    sprites.sparks[0 + INDEX_BASE] = sprite_grab(34, 0, 10, 8)
    sprites.sparks[1 + INDEX_BASE] = sprite_grab(45, 0, 7, 8)
    sprites.sparks[2 + INDEX_BASE] = sprite_grab(54, 0, 9, 8)

    sprites.powerup[0 + INDEX_BASE] = sprite_grab(0, 49, 9, 12)
    sprites.powerup[1 + INDEX_BASE] = sprite_grab(10, 49, 9, 12)
    sprites.powerup[2 + INDEX_BASE] = sprite_grab(20, 49, 9, 12)
    sprites.powerup[3 + INDEX_BASE] = sprite_grab(30, 49, 9, 12)
end

local function sprites_deinit()
    allegro5.al_destroy_bitmap(sprites.ship)

    allegro5.al_destroy_bitmap(sprites.ship_shot[0 + INDEX_BASE])
    allegro5.al_destroy_bitmap(sprites.ship_shot[1 + INDEX_BASE])

    allegro5.al_destroy_bitmap(sprites.life)

    allegro5.al_destroy_bitmap(sprites.alien[0 + INDEX_BASE])
    allegro5.al_destroy_bitmap(sprites.alien[1 + INDEX_BASE])
    allegro5.al_destroy_bitmap(sprites.alien[2 + INDEX_BASE])

    allegro5.al_destroy_bitmap(sprites.alien_shot)

    allegro5.al_destroy_bitmap(sprites.explosion[0 + INDEX_BASE])
    allegro5.al_destroy_bitmap(sprites.explosion[1 + INDEX_BASE])
    allegro5.al_destroy_bitmap(sprites.explosion[2 + INDEX_BASE])
    allegro5.al_destroy_bitmap(sprites.explosion[3 + INDEX_BASE])

    allegro5.al_destroy_bitmap(sprites.sparks[0 + INDEX_BASE])
    allegro5.al_destroy_bitmap(sprites.sparks[1 + INDEX_BASE])
    allegro5.al_destroy_bitmap(sprites.sparks[2 + INDEX_BASE])

    allegro5.al_destroy_bitmap(sprites.powerup[0 + INDEX_BASE])
    allegro5.al_destroy_bitmap(sprites.powerup[1 + INDEX_BASE])
    allegro5.al_destroy_bitmap(sprites.powerup[2 + INDEX_BASE])
    allegro5.al_destroy_bitmap(sprites.powerup[3 + INDEX_BASE])

    allegro5.al_destroy_bitmap(sprites._sheet)
end


-- --- audio ---

local sample_shot ---@type ALLEGRO_SAMPLE?
local sample_explode = {} ---@type ALLEGRO_SAMPLE[]

local function audio_init()
    allegro5.al_install_audio()
    allegro5.al_init_acodec_addon()
    allegro5.al_reserve_samples(128)

    sample_shot = allegro5.al_load_sample(ALLEGRO_WIKI_DATA_PATH .. "/audio/shot.flac")
    must_init(sample_shot, "shot sample")

    sample_explode[0 + INDEX_BASE] = allegro5.al_load_sample(ALLEGRO_WIKI_DATA_PATH .. "/audio/explode1.flac")
    must_init(sample_explode[0 + INDEX_BASE], "explode[0] sample")
    sample_explode[1 + INDEX_BASE] = allegro5.al_load_sample(ALLEGRO_WIKI_DATA_PATH .. "/audio/explode2.flac")
    must_init(sample_explode[1 + INDEX_BASE], "explode[1] sample")
end

local function audio_deinit()
    allegro5.al_destroy_sample(sample_shot)
    allegro5.al_destroy_sample(sample_explode[0 + INDEX_BASE])
    allegro5.al_destroy_sample(sample_explode[1 + INDEX_BASE])
end


-- --- fx ---

---@class FX
---@field x integer
---@field y integer
---@field frame integer
---@field spark boolean
---@field used boolean
---@overload fun(): FX
local FX = common.class({
    __name = "FX",
})

---@param self FX
function FX.__init__(self)
    self.x = 0
    self.y = 0
    self.frame = 0
    self.spark = false
    self.used = false
end

local FX_N = 128
local fx = new_table(FX, FX_N)

local function fx_init()
    for i = 1, FX_N do
        fx[i].used = false
    end
end

---@param spark boolean
---@param x integer
---@param y integer
local function fx_add(spark, x, y)
    if not spark then
        allegro5.al_play_sample(sample_explode[between(0, 2) + INDEX_BASE], 0.75, 0, 1, allegro5.ALLEGRO_PLAYMODE_ONCE,
            nil)
    end

    for i = 1, FX_N do
        if not fx[i].used then
            fx[i].x = x
            fx[i].y = y
            fx[i].frame = 0
            fx[i].spark = spark
            fx[i].used = true
            return
        end
    end
end

local function fx_update()
    for i = 1, FX_N do
        if fx[i].used then
            fx[i].frame = fx[i].frame + 1

            if (not fx[i].spark and (fx[i].frame == (EXPLOSION_FRAMES * 2)))
                or (fx[i].spark and (fx[i].frame == (SPARKS_FRAMES * 2))) then
                fx[i].used = false
            end
        end
    end
end

local function fx_draw()
    for i = 1, FX_N do
        if fx[i].used then
            local frame_display = math.floor(fx[i].frame / 2)
            local bmp =
                (function()
                    if fx[i].spark then
                        return sprites.sparks[frame_display + INDEX_BASE]
                    else
                        return sprites.explosion[frame_display + INDEX_BASE]
                    end
                end)()

            local x = fx[i].x - math.floor(allegro5.al_get_bitmap_width(bmp) / 2) ---@type integer
            local y = fx[i].y - math.floor(allegro5.al_get_bitmap_height(bmp) / 2) ---@type integer
            allegro5.al_draw_bitmap(bmp, x, y, 0)
        end
    end
end


-- --- shots ---

---@class SHOT
---@field x integer
---@field y integer
---@field dx integer
---@field dy integer
---@field frame integer
---@field ship boolean
---@field used boolean
---@overload fun(): SHOT
local SHOT = common.class({
    __name = "SHOT",
})

---@param self SHOT
function SHOT.__init__(self)
    self.x = 0
    self.y = 0
    self.dx = 0
    self.dy = 0
    self.frame = 0
    self.ship = false
    self.used = false
end

local SHOTS_N = 128
local shots = new_table(SHOT, SHOTS_N)

local function shots_init()
    for i = 1, SHOTS_N do
        shots[i].used = false
    end
end


---@param ship boolean
---@param straight boolean
---@param x integer
---@param y integer
---@return boolean
local function shots_add(ship, straight, x, y)
    allegro5.al_play_sample(
        sample_shot,
        0.3,
        0,
        (function() if ship then return 1.0 else return between_f(1.5, 1.6) end end)(),
        allegro5.ALLEGRO_PLAYMODE_ONCE,
        nil
    )

    for i = 1, SHOTS_N do
        if not shots[i].used then
            shots[i].ship = ship

            if ship then
                shots[i].x = x - math.floor(SHIP_SHOT_W / 2)
                shots[i].y = y
            else -- alien
                shots[i].x = x - math.floor(ALIEN_SHOT_W / 2)
                shots[i].y = y - math.floor(ALIEN_SHOT_H / 2)

                if straight then
                    shots[i].dx = 0
                    shots[i].dy = 2
                else
                    shots[i].dx = between(-2, 2)
                    shots[i].dy = between(-2, 2)
                end

                -- if the shot has no speed, don't bother
                if shots[i].dx == 0 and shots[i].dy == 0 then
                    return true
                end

                shots[i].frame = 0
            end

            shots[i].frame = 0
            shots[i].used = true

            return true
        end
    end
    return false
end

local function shots_update()
    for i = 1, SHOTS_N do
        if shots[i].used then
            local continue = false
            if shots[i].ship then
                shots[i].y = shots[i].y - (5)

                if shots[i].y < -SHIP_SHOT_H then
                    shots[i].used = false
                    continue = true
                end
            else -- alien
                shots[i].x = shots[i].x + shots[i].dx
                shots[i].y = shots[i].y + shots[i].dy

                if (shots[i].x < -ALIEN_SHOT_W)
                    or (shots[i].x > BUFFER_W)
                    or (shots[i].y < -ALIEN_SHOT_H)
                    or (shots[i].y > BUFFER_H) then
                    shots[i].used = false
                    continue = true
                end
            end

            if not continue then
                shots[i].frame = shots[i].frame + 1
            end
        end
    end
end

---@param ship boolean
---@param x integer
---@param y integer
---@param w integer
---@param h integer
---@return boolean
local function shots_collide(ship, x, y, w, h)
    for i = 1, SHOTS_N do
        -- don't collide with one's own shots
        if shots[i].used and shots[i].ship ~= ship then
            local sw, sh = 0, 0 ---@type integer, integer
            if ship then
                sw = ALIEN_SHOT_W
                sh = ALIEN_SHOT_H
            else
                sw = SHIP_SHOT_W
                sh = SHIP_SHOT_H
            end

            if collide(x, y, x + w, y + h, shots[i].x, shots[i].y, shots[i].x + sw, shots[i].y + sh) then
                fx_add(true, shots[i].x + math.floor(sw / 2), shots[i].y + math.floor(sh / 2))
                shots[i].used = false
                return true
            end
        end
    end

    return false
end

local function shots_draw()
    for i = 1, SHOTS_N do
        if shots[i].used then
            local frame_display = math.floor(shots[i].frame / 2) % 2
            if shots[i].ship then
                allegro5.al_draw_bitmap(sprites.ship_shot[frame_display + INDEX_BASE], shots[i].x,
                    shots[i].y, 0)
            else -- alien
                local tint = (function()
                    if frame_display ~= 0 then
                        return allegro5.al_map_rgb_f(1, 1, 1)
                    else
                        return allegro5.al_map_rgb_f(0.5, 0.5, 0.5)
                    end
                end)()

                allegro5.al_draw_tinted_bitmap(sprites.alien_shot, tint, shots[i].x, shots[i].y, 0)
            end
        end
    end
end


-- --- ship ---

local SHIP_SPEED = 3
local SHIP_MAX_X = (BUFFER_W - SHIP_W)
local SHIP_MAX_Y = (BUFFER_H - SHIP_H)

---@class SHIP
---@field x integer
---@field y integer
---@field shot_timer integer
---@field lives integer
---@field respawn_timer integer
---@field invincible_timer integer
---@overload fun(): SHIP
local SHIP = common.class({
    __name = "SHIP",
})

---@param self SHIP
function SHIP.__init__(self)
    self.x = 0
    self.y = 0
    self.shot_timer = 0
    self.lives = 0
    self.respawn_timer = 0
    self.invincible_timer = 0
end

local ship = SHIP()

local function ship_init()
    ship.x = math.floor(BUFFER_W / 2) - math.floor(SHIP_W / 2)
    ship.y = math.floor(BUFFER_H / 2) - math.floor(SHIP_H / 2)
    ship.shot_timer = 0
    ship.lives = 3
    ship.respawn_timer = 0
    ship.invincible_timer = 120
end

local function ship_update()
    if ship.lives < 0 then
        return
    end

    if ship.respawn_timer ~= 0 then
        ship.respawn_timer = ship.respawn_timer - 1
        return
    end

    if key[allegro5.ALLEGRO_KEY_LEFT + INDEX_BASE] ~= 0 then
        ship.x = ship.x - (SHIP_SPEED)
    end
    if key[allegro5.ALLEGRO_KEY_RIGHT + INDEX_BASE] ~= 0 then
        ship.x = ship.x + (SHIP_SPEED)
    end
    if key[allegro5.ALLEGRO_KEY_UP + INDEX_BASE] ~= 0 then
        ship.y = ship.y - (SHIP_SPEED)
    end
    if key[allegro5.ALLEGRO_KEY_DOWN + INDEX_BASE] ~= 0 then
        ship.y = ship.y + (SHIP_SPEED)
    end

    if ship.x < 0 then
        ship.x = 0
    end
    if ship.y < 0 then
        ship.y = 0
    end

    if ship.x > SHIP_MAX_X then
        ship.x = SHIP_MAX_X
    end
    if ship.y > SHIP_MAX_Y then
        ship.y = SHIP_MAX_Y
    end

    if ship.invincible_timer ~= 0 then
        ship.invincible_timer = ship.invincible_timer - 1
    else
        if shots_collide(true, ship.x, ship.y, SHIP_W, SHIP_H) then
            local x = ship.x + math.floor(SHIP_W / 2) ---@type integer
            local y = ship.y + math.floor(SHIP_H / 2) ---@type integer
            fx_add(false, x, y)
            fx_add(false, x + 4, y + 2)
            fx_add(false, x - 2, y - 4)
            fx_add(false, x + 1, y - 5)

            ship.lives = ship.lives - 1
            ship.respawn_timer = 90
            ship.invincible_timer = 180
        end
    end

    if ship.shot_timer ~= 0 then
        ship.shot_timer = ship.shot_timer - 1
    elseif key[allegro5.ALLEGRO_KEY_X + INDEX_BASE] ~= 0 or key[allegro5.ALLEGRO_KEY_SPACE + INDEX_BASE] ~= 0 then
        local x = ship.x + math.floor(SHIP_W / 2) ---@type integer
        if shots_add(true, false, x, ship.y) then
            ship.shot_timer = 5
        end
    end
end

local function ship_draw()
    if ship.lives < 0 then
        return
    end
    if ship.respawn_timer ~= 0 then
        return
    end
    if (math.floor(ship.invincible_timer / 2) % 3) == 1 then
        return
    end

    allegro5.al_draw_bitmap(sprites.ship, ship.x, ship.y, 0)
end


-- --- aliens ---

local ALIEN_TYPE_BUG = 0
local ALIEN_TYPE_ARROW = 1
local ALIEN_TYPE_THICCBOI = 2
local ALIEN_TYPE_N = 3

---@alias ALIEN_TYPE `ALIEN_TYPE_BUG` | `ALIEN_TYPE_ARROW` | `ALIEN_TYPE_THICCBOI` | `ALIEN_TYPE_N`

---@class ALIEN
---@field x integer
---@field y integer
---@field type ALIEN_TYPE
---@field shot_timer integer
---@field blink integer
---@field life integer
---@field used boolean
---@overload fun(): ALIEN
local ALIEN = common.class({
    __name = "ALIEN",
})

---@param self ALIEN
function ALIEN.__init__(self)
    self.x = 0
    self.y = 0
    self.type = ALIEN_TYPE_BUG
    self.shot_timer = 0
    self.blink = 0
    self.life = 0
    self.used = false
end

local ALIENS_N = 16
local aliens = new_table(ALIEN, ALIENS_N)

local function aliens_init()
    for i = 1, ALIENS_N do
        aliens[i].used = false
    end
end

local function aliens_update()
    local new_quota = (function()
        if (frames % 120) ~= 0 then
            return 0
        else
            return between(2, 4)
        end
    end)()

    local new_x = between(10, BUFFER_W - 50) ---@type integer

    for i = 1, ALIENS_N do
        if not aliens[i].used then
            -- if this alien is unused, should it spawn?
            if new_quota > 0 then
                new_x = new_x + between(40, 80) ---@type integer
                if new_x > (BUFFER_W - 60) then
                    new_x = new_x - (BUFFER_W - 60)
                end

                aliens[i].x = new_x

                aliens[i].y = between(-40, -30)
                aliens[i].type = between(0, ALIEN_TYPE_N)
                aliens[i].shot_timer = between(1, 99)
                aliens[i].blink = 0
                aliens[i].used = true


                if aliens[i].type == ALIEN_TYPE_BUG then
                    aliens[i].life = 4
                elseif aliens[i].type == ALIEN_TYPE_ARROW then
                    aliens[i].life = 2
                elseif aliens[i].type == ALIEN_TYPE_THICCBOI then
                    aliens[i].life = 12
                end

                new_quota = new_quota - 1
            end
        else
            if aliens[i].type == ALIEN_TYPE_BUG then
                if frames % 2 ~= 0 then
                    aliens[i].y = aliens[i].y + 1
                end
            elseif aliens[i].type == ALIEN_TYPE_ARROW then
                aliens[i].y = aliens[i].y + 1
            elseif aliens[i].type == ALIEN_TYPE_THICCBOI then
                if frames % 4 == 0 then
                    aliens[i].y = aliens[i].y + 1
                end
            end

            if aliens[i].y >= BUFFER_H then
                aliens[i].used = false
            else
                if aliens[i].blink ~= 0 then
                    aliens[i].blink = aliens[i].blink - 1
                end

                if shots_collide(false, aliens[i].x, aliens[i].y, ALIEN_W[aliens[i].type + INDEX_BASE], ALIEN_H[aliens[i].type + INDEX_BASE]) then
                    aliens[i].life = aliens[i].life - 1
                    aliens[i].blink = 4
                end

                local cx = aliens[i].x + math.floor(ALIEN_W[aliens[i].type + INDEX_BASE] / 2)
                local cy = aliens[i].y + math.floor(ALIEN_H[aliens[i].type + INDEX_BASE] / 2)

                if aliens[i].life <= 0 then
                    fx_add(false, cx, cy)

                    if aliens[i].type == ALIEN_TYPE_BUG then
                        score = score + (200)
                    elseif aliens[i].type == ALIEN_TYPE_ARROW then
                        score = score + (150)
                    elseif aliens[i].type == ALIEN_TYPE_THICCBOI then
                        score = score + (800)
                        fx_add(false, cx - 10, cy - 4)
                        fx_add(false, cx + 4, cy + 10)
                        fx_add(false, cx + 8, cy + 8)
                    end

                    aliens[i].used = false
                else
                    aliens[i].shot_timer = aliens[i].shot_timer - 1
                    if aliens[i].shot_timer == 0 then
                        if aliens[i].type == ALIEN_TYPE_BUG then
                            shots_add(false, false, cx, cy)
                            aliens[i].shot_timer = 150
                        elseif aliens[i].type == ALIEN_TYPE_ARROW then
                            shots_add(false, true, cx, aliens[i].y)
                            aliens[i].shot_timer = 80
                        elseif aliens[i].type == ALIEN_TYPE_THICCBOI then
                            shots_add(false, true, cx - 5, cy)
                            shots_add(false, true, cx + 5, cy)
                            shots_add(false, true, cx - 5, cy + 8)
                            shots_add(false, true, cx + 5, cy + 8)
                            aliens[i].shot_timer = 200
                        end
                    end
                end
            end
        end
    end
end

local function aliens_draw()
    for i = 1, ALIENS_N do
        if aliens[i].used and aliens[i].blink <= 2 then
            allegro5.al_draw_bitmap(sprites.alien[aliens[i].type + INDEX_BASE], aliens[i].x,
                aliens[i].y, 0)
        end
    end
end


-- --- stars ---

---@class STAR
---@field y number
---@field speed number
---@overload fun(): STAR
local STAR = common.class({
    __name = "STAR",
})

---@param self STAR
function STAR.__init__(self)
    self.y = 0
    self.speed = 0
end

local STARS_N = math.floor(BUFFER_W / 2) - 1
local stars = new_table(STAR, STARS_N)

local function stars_init()
    for i = 1, STARS_N do
        stars[i].y = between_f(0, BUFFER_H)
        stars[i].speed = between_f(0.1, 1)
    end
end

local function stars_update()
    for i = 1, STARS_N do
        stars[i].y = stars[i].y + stars[i].speed
        if stars[i].y >= BUFFER_H then
            stars[i].y = 0
            stars[i].speed = between_f(0.1, 1)
        end
    end
end

local function stars_draw()
    local star_x = 1.5
    for i = 1, STARS_N do
        local l = stars[i].speed * 0.8
        allegro5.al_draw_pixel(star_x, stars[i].y, allegro5.al_map_rgb_f(l, l, l))
        star_x = star_x + 2
    end
end


-- --- hud ---

local font ---@type ALLEGRO_FONT?
local score_display = 0 ---@type integer

local function hud_init()
    font = allegro5.al_create_builtin_font()
    must_init(font, "font")

    score_display = 0
    fps = common.FPS()
end

local function hud_deinit()
    allegro5.al_destroy_font(font)
end

local function hud_update()
    if frames % 2 ~= 0 then
        return
    end

    for i = 5, 0 - INDEX_BASE * -1, -1 do
        local diff = bit.lshift(1, i)
        if score_display <= (score - diff) then
            score_display = score_display + diff
        end
    end
end

local function hud_draw()
    allegro5.al_draw_text(
        font,
        allegro5.al_map_rgb_f(1, 1, 1),
        1, 1,
        0,
        string.format("%06d", score_display)
    )

    local spacing = LIFE_W + 1
    for i = 0, ship.lives - INDEX_BASE do
        allegro5.al_draw_bitmap(sprites.life, 1 + (i * spacing), 10, 0)
    end

    if ship.lives < 0 then
        allegro5.al_draw_text(
            font,
            allegro5.al_map_rgb_f(1, 1, 1),
            math.floor(BUFFER_W / 2), math.floor(BUFFER_H / 2),
            allegro5.ALLEGRO_ALIGN_CENTER,
            "G A M E  O V E R"
        )
    end

    allegro5.al_draw_text(
        font,
        allegro5.al_map_rgb_f(1, 1, 1),
        1, 19,
        0,
        string.format('FPS: %.2f', fps:compute())
    )
end


--[[ display a commandline usage message --]]
---@param code integer
---@return integer code
local function usage(code)
    printf(
        "\n"
        .. "Allegro Vivace – Gameplay\n"
        .. "\n"
        .. "Usage: game w h [options]\n"
        .. "\n"
        .. "The w and h values set your desired screen resolution.\n"
        .. "What modes are available will depend on your hardware.\n"
        .. "\n"
        .. "Available options:\n"
        .. "\n"
        .. "\t--help,-help,-h Print this help and exit successfully.\n"
        .. "\t--fps <integer> Choose the desired game fps. (60 by default)\n"
        .. "\t-fullscreen     Enables full screen mode. (w and h are optional)\n"
        .. "\n"
        .. "Example usage:\n"
        .. "\n"
        .. "\tgame 640 480\n"
    )

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end

    os.exit(code)
    return code
end

---@param argv string[]
---@return integer fps
local function parse_args(argv)
    local argc = #argv

    local w, h = 0, 0 ---@type integer, integer
    local n = 0 ---@type integer?
    local fullscreen = false

    --[[ parse the commandline --]]
    local j = 0
    while j < argc do
        j = j + 1

        if argv[j] == "--fps" then
            j = j + 1
            n = tonumber(argv[j], 10)
            if n == nil or n == 0 then
                io.stderr:write(string.format("fps must be an integer greater than 0. Provided: %s\n", tostring(argv[j])))
                return usage(1)
            end
            desired_fps = n
        elseif argv[j] == "-fullscreen" then
            fullscreen = true
        elseif argv[j] == "-h" or argv[j] == "-help" or argv[j] == "--help" then
            return usage(0)
        else
            n = tonumber(argv[j], 10)

            if n == nil or n == 0 then
                return usage(1)
            end

            if w == 0 then
                w = n
            elseif h == 0 then
                h = n
            else
                return usage(1)
            end
        end
    end

    if fullscreen then
        ---@param modes { width: integer, height: integer }[]
        ---@param m ALLEGRO_DISPLAY_MODE
        ---@return boolean
        local function add_mode(modes, m)
            for i = 1, #modes do
                if modes[i].width == m.width and modes[i].height == m.height then
                    return false
                end
            end

            modes[#modes + 1] = {
                width = m.width,
                height = m.height,
            }

            return true
        end

        -- check that the requested screen size is available
        local can_display_mode = false
        local modes = {} ---@type { width: integer, height: integer }[]
        local num_modes = allegro5.al_get_num_display_modes()

        for i = 0, num_modes - INDEX_BASE do
            local m = allegro5.ALLEGRO_DISPLAY_MODE()
            allegro5.al_get_display_mode(i, m)
            add_mode(modes, m)
            can_display_mode = m.width == w and m.height == h
        end

        if w ~= 0 and h ~= 0 then
            if can_display_mode then
                DISP_FLAGS = bit.bor(DISP_FLAGS, allegro5.ALLEGRO_FULLSCREEN)
            else
                printf("Invalid full screen size %d x %d\n", w, h)
                printf("Available modes are:\n", w, h)
                for _, m in ipairs(modes) do
                    printf("%s %d x %d\n", "Fullscreen", m.width, m.height)
                end
                printf("Fallback to windowed fullscreen\n")
                DISP_FLAGS = bit.bor(DISP_FLAGS, allegro5.ALLEGRO_FULLSCREEN_WINDOW)
            end
        else
            w = modes[#modes].width
            h = modes[#modes].height
            DISP_FLAGS = bit.bor(DISP_FLAGS, allegro5.ALLEGRO_FULLSCREEN)
            printf("%s %d x %d\n", "Fullscreen", w, h)
        end
    else
        DISP_FLAGS = bit.bor(DISP_FLAGS, bit.bor(allegro5.ALLEGRO_WINDOWED, allegro5.ALLEGRO_RESIZABLE))
    end

    if w == 0 or h == 0 then
        if w == 0 and h == 0 or bit.band(DISP_FLAGS, allegro5.ALLEGRO_FULLSCREEN_WINDOW) ~= 0 then
            w = DISP_W
            h = DISP_H
        else
            return usage(1)
        end
    end

    if w ~= DISP_W or h ~= DISP_H then
        BUFFER_W = math.floor(w / DISP_SCALE)
        BUFFER_H = math.floor(h / DISP_SCALE)
        DISP_W = (BUFFER_W * DISP_SCALE)
        DISP_H = (BUFFER_H * DISP_SCALE)
        SHIP_MAX_X = (BUFFER_W - SHIP_W)
        SHIP_MAX_Y = (BUFFER_H - SHIP_H)

        local old_STARS_N = STARS_N
        STARS_N = math.floor(BUFFER_W / 2) - 1
        if old_STARS_N > STARS_N then
            for i = old_STARS_N, STARS_N + 1, -1 do
                stars[i] = nil
            end
        else
            for i = old_STARS_N + 1, STARS_N do
                stars[i] = STAR()
            end
        end
    end

    return desired_fps
end

-- --- main ---

local function main(argv)
    must_init(allegro5.al_init(), "allegro")

    local rfps = parse_args(argv)

    must_init(allegro5.al_install_keyboard(), "keyboard")

    local timer = allegro5.al_create_timer(1.0 / rfps)
    must_init(timer, "timer")

    local queue = allegro5.al_create_event_queue()
    must_init(queue, "queue")

    disp_init()

    audio_init()

    must_init(allegro5.al_init_image_addon(), "image")
    sprites_init()

    hud_init()

    must_init(allegro5.al_init_primitives_addon(), "primitives")

    must_init(allegro5.al_install_audio(), "audio")
    must_init(allegro5.al_init_acodec_addon(), "audio codecs")
    must_init(allegro5.al_reserve_samples(16), "reserve samples")

    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(disp))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    keyboard_init()
    fx_init()
    shots_init()
    ship_init()
    aliens_init()
    stars_init()

    frames = 0
    score = 0

    local done = false
    local redraw = true
    local event = allegro5.ALLEGRO_EVENT()

    allegro5.al_start_timer(timer)

    while true do
        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            fx_update()
            shots_update()
            stars_update()
            ship_update()
            aliens_update()
            hud_update()

            if key[allegro5.ALLEGRO_KEY_ESCAPE + INDEX_BASE] ~= 0 then
                done = true
            end

            redraw = true
            frames = frames + 1
            fps:frame()
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(disp)
            disp_transform_update()
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            done = true
        end

        if done then
            break
        end

        keyboard_update(event)

        --[[ toggle fullscreen window --]]
        if key[allegro5.ALLEGRO_KEY_F + INDEX_BASE] ~= 0 then
            local flags = allegro5.al_get_display_flags(disp)
            if bit.band(flags, allegro5.ALLEGRO_FULLSCREEN) == 0 then
                allegro5.al_set_display_flag(disp, allegro5.ALLEGRO_FULLSCREEN_WINDOW,
                    bit.band(flags, allegro5.ALLEGRO_FULLSCREEN_WINDOW) == 0)

                while key[allegro5.ALLEGRO_KEY_F + INDEX_BASE] ~= 0 do
                    allegro5.al_wait_for_event(queue, event)
                    keyboard_update(event)
                end

                disp_transform_update()
            end
        end

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            disp_pre_draw()
            allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))

            stars_draw()
            aliens_draw()
            shots_draw()
            fx_draw()
            ship_draw()

            hud_draw()

            disp_post_draw()
            redraw = false
        end
    end

    sprites_deinit()
    hud_deinit()
    audio_deinit()
    disp_deinit()
    allegro5.al_destroy_timer(timer)
    allegro5.al_destroy_event_queue(queue)


    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end

    return 0
end

os.exit(main(rawget(_G, "arg") or {}))
