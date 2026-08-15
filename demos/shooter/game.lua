---@class game
---@field score integer
---@field player_x_pos integer
---@field player_hit boolean
---@field ship_state integer
---@field skip_count integer
local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/shooter/game.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local a4_aux = require("demos.speed.a4_aux")
local aster ---@module "aster"
local bullet_m = require("bullet")
local data_m = require("data")
local demo = require("demo")
local expl = require("expl")
local star = require("star")

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local clear_keybuf = a4_aux.clear_keybuf
local draw_sprite = a4_aux.draw_sprite
local key = a4_aux.key
local keypressed = a4_aux.keypressed
local makecol = a4_aux.makecol
local MIN = a4_aux.MIN
local play_midi = a4_aux.play_midi
local play_sample = a4_aux.play_sample
local poll_input = a4_aux.poll_input
local rest = a4_aux.rest
local retrace_count = a4_aux.retrace_count
local stop_midi = a4_aux.stop_midi
local stretch_blit = a4_aux.stretch_blit
local textout = a4_aux.textout
local textout_centre = a4_aux.textout_centre

local add_asteroid ---@type fun()
local draw_asteroids ---@type fun()
local init_asteroids ---@type fun()
local move_asteroids ---@type fun()
local scroll_asteroids ---@type fun()

local add_bullet = bullet_m.add_bullet
local delete_bullet = bullet_m.delete_bullet
local draw_bullets = bullet_m.draw_bullets
local move_bullets = bullet_m.move_bullets

local END_FONT = data_m.END_FONT
local ENGINE1 = data_m.ENGINE1
local ENGINE_SPL = data_m.ENGINE_SPL
local GAME_MUSIC = data_m.GAME_MUSIC
local GAME_PAL = data_m.GAME_PAL
local GO_BMP = data_m.GO_BMP
local INTRO_BMP_1 = data_m.INTRO_BMP_1
local INTRO_BMP_2 = data_m.INTRO_BMP_2
local INTRO_BMP_3 = data_m.INTRO_BMP_3
local INTRO_BMP_4 = data_m.INTRO_BMP_4
local SHIP1 = data_m.SHIP1
local SHIP2 = data_m.SHIP2
local SHIP3 = data_m.SHIP3
local SHIP4 = data_m.SHIP4
local SHIP5 = data_m.SHIP5
local SHOOT_SPL = data_m.SHOOT_SPL
local TITLE_FONT = data_m.TITLE_FONT
local data = data_m.data

local fade_out = demo.fade_out
local get_palette = demo.get_palette
local set_palette = demo.set_palette

local EXPLODE_FLAG = expl.EXPLODE_FLAG
local EXPLODE_FRAMES = expl.EXPLODE_FRAMES
local explosion = expl.explosion

local draw_starfield_2d = star.draw_starfield_2d
local init_starfield_2d = star.init_starfield_2d
local scroll_stars = star.scroll_stars
local starfield_2d = star.starfield_2d


--[[ for doing stereo sound effects --]]
---@param x integer
---@return integer
local function PAN(x)
    return math.floor(x * 256 / demo.SCREEN_W)
end
exports.PAN = PAN

local SPEED_SHIFT = 3
exports.SPEED_SHIFT = SPEED_SHIFT

local score ---@type integer
local player_x_pos ---@type integer
local player_hit ---@type boolean
local ship_state ---@type integer
local skip_count ---@type integer

function exports.init()
   aster = require("aster")

   add_asteroid = aster.add_asteroid
   draw_asteroids = aster.draw_asteroids
   init_asteroids = aster.init_asteroids
   move_asteroids = aster.move_asteroids
   scroll_asteroids = aster.scroll_asteroids
end

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/shooter/game.c
--]]

local BULLET_DELAY = 20 ---@type integer

--[[ the current score --]]
score = 0
local score_buf ---@type string?
player_x_pos = 0
player_hit = false
ship_state = 0
skip_count = 0

--[[ info about the state of the game --]]
local dead = false ---@type boolean
local xspeed, yspeed, ycounter = 0, 0, 0 ---@type integer, integer, integer
local ship_burn = false ---@type boolean
local ship_count = 0 ---@type integer
local skip_speed = 0 ---@type integer
local frame_count, fps = 0, 0 ---@type integer, integer
local game_time = 0 ---@type integer
local prev_bullet_time = 0 ---@type integer
local new_asteroid_time = 0 ---@type integer
local score_pos = 0 ---@type integer
local engine = allegro5.ALLEGRO_SAMPLE_ID()

local MAX_SPEED = 32 ---@type integer



--[[ handles fade effects and timing for the ready, steady, go messages --]]
---@param music_pos integer
---@param fade_speed integer
---@return boolean
local function fade_intro_item(music_pos, fade_speed)
    set_palette(data[GAME_PAL + INDEX_BASE].dat)
    fade_out(fade_speed)
    return keypressed()
end



--[[ draws one of the ready, steady, go messages --]]
---@param item integer
---@param size integer
local function draw_intro_item(item, size)
    local b = data[item + INDEX_BASE].dat --[[@as ALLEGRO_BITMAP --]]
    local w = MIN(demo.SCREEN_W, math.floor(demo.SCREEN_W * 2 / size)) ---@type integer
    local h = math.floor(demo.SCREEN_H / size) ---@type integer

    --clear_bitmap(screen);
    local bw = allegro5.al_get_bitmap_width(b)
    local bh = allegro5.al_get_bitmap_height(b)
    allegro5.al_clear_to_color(makecol(0, 0, 0))
    stretch_blit(b, 0, 0, bw, bh, math.floor((demo.SCREEN_W - w) / 2),
        math.floor((demo.SCREEN_H - h) / 2), w, h)
    allegro5.al_flip_display()
end



--[[ the main game update function --]]
local function move_everyone()
    local bullet ---@type BULLET?

    score = score + 1

    if player_hit then
        --[[ player dead --]]
        if skip_count <= 0 then
            if ship_state >= EXPLODE_FLAG + EXPLODE_FRAMES - 1 then
                ship_count = ship_count - 1
                if ship_count <= 0 then
                    dead = true
                else
                    player_hit = false
                end
            else
                ship_state = ship_state + 1
            end

            if yspeed ~= 0 then
                yspeed = yspeed - 1
            end
        end
    else
        if skip_count <= 0 then
            if (key[allegro5.ALLEGRO_KEY_LEFT]) then -- || (joy[0].stick[0].axis[0].d1)) {
                --[[ moving left --]]
                if xspeed > -MAX_SPEED then
                    xspeed = xspeed - (2)
                end
            elseif (key[allegro5.ALLEGRO_KEY_RIGHT]) then -- || (joy[0].stick[0].axis[0].d2)) {
                --[[ moving right --]]
                if xspeed < MAX_SPEED then
                    xspeed = xspeed + (2)
                end
            else
                --[[ decelerate --]]
                if xspeed > 0 then
                    xspeed = xspeed - (2)
                elseif xspeed < 0 then
                    xspeed = xspeed + (2)
                end
            end
        end

        --[[ which ship sprite to use? --]]
        if xspeed < -24 then
            ship_state = SHIP1
        elseif xspeed < -2 then
            ship_state = SHIP2
        elseif xspeed <= 2 then
            ship_state = SHIP3
        elseif xspeed <= 24 then
            ship_state = SHIP4
        else
            ship_state = SHIP5
        end

        --[[ move player --]]
        player_x_pos = player_x_pos + (xspeed)
        if player_x_pos < (bit.lshift(32, SPEED_SHIFT)) then
            player_x_pos = (bit.lshift(32, SPEED_SHIFT))
            xspeed = 0
        elseif player_x_pos >= (bit.lshift((demo.SCREEN_W - 32), SPEED_SHIFT)) then
            player_x_pos = (bit.lshift((demo.SCREEN_W - 32), SPEED_SHIFT))
            xspeed = 0
        end

        if skip_count <= 0 then
            if (key[allegro5.ALLEGRO_KEY_UP]) then -- || (joy[0].stick[0].axis[1].d1)) {
                --[[ firing thrusters --]]
                if yspeed < MAX_SPEED then
                    if yspeed == 0 then
                        allegro5.al_stop_sample(engine)
                        allegro5.al_play_sample(data[ENGINE_SPL + INDEX_BASE].dat, 0.9,
                            -1 + 2 * PAN(bit.rshift(player_x_pos, SPEED_SHIFT)) / 255.0,
                            1.0, allegro5.ALLEGRO_PLAYMODE_LOOP, engine)
                    else
                        --[[ fade in sample while speeding up --]]
                        local si = allegro5.al_lock_sample_id(engine)
                        allegro5.al_set_sample_instance_gain(si, yspeed * 64 / MAX_SPEED / 255.0)
                        allegro5.al_set_sample_instance_pan(si,
                            -1 + 2 * PAN(bit.rshift(player_x_pos, SPEED_SHIFT)) / 255.0)
                        allegro5.al_unlock_sample_id(engine)
                    end
                    yspeed = yspeed + 1
                else
                    --[[ adjust pan while the sample is looping --]]
                    local si = allegro5.al_lock_sample_id(engine)
                    allegro5.al_set_sample_instance_gain(si, 64 / 255.0)
                    allegro5.al_set_sample_instance_pan(si, -1 + 2 * PAN(bit.rshift(player_x_pos, SPEED_SHIFT)) / 255.0)
                    allegro5.al_unlock_sample_id(engine)
                end

                ship_burn = true
                score = score + 1
            else
                --[[ not firing thrusters --]]
                if yspeed ~= 0 then
                    yspeed = yspeed - 1
                    if yspeed == 0 then
                        allegro5.al_stop_sample(engine)
                    else
                        --[[ fade out and reduce frequency when slowing down --]]
                        local si = allegro5.al_lock_sample_id(engine)
                        allegro5.al_set_sample_instance_gain(si, yspeed * 64 / MAX_SPEED / 255.0)
                        allegro5.al_set_sample_instance_pan(si,
                            -1 + 2 * PAN(bit.rshift(player_x_pos, SPEED_SHIFT)) / 255.0)
                        allegro5.al_set_sample_instance_speed(si, (500 + yspeed * 500 / MAX_SPEED) / 1000.0)
                        allegro5.al_unlock_sample_id(engine)
                    end
                end

                ship_burn = false
            end
        end
    end

    --[[ if going fast, move everyone else down to compensate --]]
    if yspeed ~= 0 then
        ycounter = ycounter + (yspeed)

        while ycounter >= (bit.lshift(1, SPEED_SHIFT)) do
            bullet = bullet_m.bullet_list
            while bullet do
                bullet.y = bullet.y + 1
                bullet = bullet.next
            end

            scroll_stars()

            scroll_asteroids()

            ycounter = ycounter - bit.lshift(1, SPEED_SHIFT) ---@type integer
        end
    end

    move_bullets()

    starfield_2d()

    --[[ fire bullet? --]]
    if not player_hit then
        if key[allegro5.ALLEGRO_KEY_SPACE] or key[allegro5.ALLEGRO_KEY_ENTER] or key[allegro5.ALLEGRO_KEY_LCTRL] or key[allegro5.ALLEGRO_KEY_RCTRL] then
            -- ||(joy[0].button[0].b) || (joy[0].button[1].b)) {
            if prev_bullet_time + BULLET_DELAY < game_time then
                bullet = add_bullet((bit.rshift(player_x_pos, SPEED_SHIFT)) - 2, demo.SCREEN_H - 64)
                if bullet then
                    play_sample(data[SHOOT_SPL + INDEX_BASE].dat, 100, PAN(bullet.x), 1000, false)
                    prev_bullet_time = game_time
                end
            end
        end
    end

    move_asteroids()

    if skip_count <= 0 then
        skip_count = skip_speed

        --[[ make a new alien? --]]
        new_asteroid_time = new_asteroid_time + 1 ---@type integer

        if new_asteroid_time > 600 then
            add_asteroid()
            new_asteroid_time = 0
        end
    else
        skip_count = skip_count - 1
    end
end



--[[ main screen update function --]]
local function draw_screen()
    local x = 0
    local spr ---@type ALLEGRO_BITMAP?

    --acquire_bitmap(bmp);
    allegro5.al_clear_to_color(makecol(0, 0, 0))

    draw_starfield_2d()

    --[[ draw the player --]]
    x = bit.rshift(player_x_pos, SPEED_SHIFT)

    if (ship_burn) and (ship_state < EXPLODE_FLAG) then
        spr = data[ENGINE1 + math.floor(retrace_count() / 4) % 7 + INDEX_BASE].dat
        local sprw = allegro5.al_get_bitmap_width(spr)
        draw_sprite(spr, x - math.floor(sprw / 2), demo.SCREEN_H - 24)
    end

    if ship_state >= EXPLODE_FLAG then
        spr = explosion[ship_state - EXPLODE_FLAG + INDEX_BASE]
    else
        spr = data[ship_state + INDEX_BASE].dat --[[@as ALLEGRO_BITMAP --]]
    end

    local sprw = allegro5.al_get_bitmap_width(spr)
    local sprh = allegro5.al_get_bitmap_height(spr)
    draw_sprite(spr, x - math.floor(sprw / 2), demo.SCREEN_H - 42 - math.floor(sprh / 2))

    --[[ draw the asteroids --]]
    draw_asteroids()

    --[[ draw the bullets --]]
    draw_bullets()

    --[[ draw the score and fps information --]]
    if fps ~= 0 then
        score_buf = string.format("Lives: %d - Score: %d - (%d fps)",
            ship_count, score, fps)
    else
        score_buf = string.format("Lives: %d - Score: %d", ship_count, score)
    end

    textout(data[TITLE_FONT + INDEX_BASE].dat, score_buf, 0, 0, get_palette(7))

    --release_bitmap(bmp);
end



local function move_score()
    score_pos = score_pos + 1
    if score_pos > demo.SCREEN_H then
        score_pos = 0
    end
end



local function draw_score()
    local tr = allegro5.ALLEGRO_TRANSFORM()
    allegro5.al_identity_transform(tr)
    allegro5.al_rotate_transform(tr, score_pos * allegro5.ALLEGRO_PI / 300)
    allegro5.al_translate_transform(tr, score_pos, score_pos)
    allegro5.al_use_transform(tr)
    textout_centre(data[END_FONT + INDEX_BASE].dat, "GAME OVER", 0, -24, get_palette(2))
    score_buf = string.format("Score: %d", score)
    textout_centre(data[END_FONT + INDEX_BASE].dat, score_buf, 0, 24, get_palette(2))
    allegro5.al_identity_transform(tr)
    allegro5.al_use_transform(tr)
end


local function run_game()
    local esc = false
    local prev_update_time = 0

    allegro5.al_clear_to_color(makecol(0, 0, 0))

    clear_keybuf()

    set_palette(data[GAME_PAL + INDEX_BASE].dat)

    game_time = 0
    prev_bullet_time = 0
    prev_update_time = 0
    local speed = 6400 / demo.SCREEN_W
    local t0 = allegro5.al_get_time()
    local fps_t0 = t0

    if speed < 4 then
        speed = 4
    end

    --[[ main game loop --]]
    while not esc do
        local updated = 0
        local t = allegro5.al_get_time()

        poll_input()
        --poll_joystick();

        game_time = math.floor((t - t0) * 1000 / speed)
        if t > fps_t0 + 1 then
            fps_t0 = t
            fps = frame_count
            frame_count = 0
        end

        while prev_update_time < game_time do
            if dead then
                move_score()
            else
                move_everyone()
                if dead then
                    clear_keybuf()
                end
            end
            prev_update_time = prev_update_time + 1
            updated = 1
        end

        if demo.max_fps or updated then
            draw_screen()
            if dead then
                draw_score()
            end

            allegro5.al_flip_display()

            frame_count = frame_count + 1
        end

        --[[ rest for a short while if we're not in CPU-hog mode and too fast --]]
        if not demo.max_fps and not updated then
            rest(1)
        end

        poll_input()

        if key[allegro5.ALLEGRO_KEY_ESCAPE] or (dead and (
                keypressed())) then -- || joy[0].button[0].b || joy[0].button[1].b)))
            esc = true
        end
    end

    --[[ cleanup --]]
    allegro5.al_stop_sample(engine)

    while bullet_m.bullet_list do
        delete_bullet(bullet_m.bullet_list)
    end

    if esc then
        repeat
            poll_input()
        until not (key[allegro5.ALLEGRO_KEY_ESCAPE])

        fade_out(5)
        return
    end

    clear_keybuf()
    fade_out(5)
end

--[[ sets up and plays the game --]]
local function play_game()
    stop_midi()

    --[[ set up a load of globals --]]
    player_hit = false; dead = player_hit
    player_x_pos = bit.lshift(math.floor(demo.SCREEN_W / 2), SPEED_SHIFT)
    ycounter = 0; yspeed = ycounter; xspeed = yspeed
    ship_state = SHIP3
    ship_burn = false
    ship_count = 3; --[[ 3 lives instead of one... --]]
    fps = 0; frame_count = fps
    bullet_m.bullet_list = nil
    score = 0
    score_pos = 0

    skip_count = 0
    if demo.SCREEN_W < 400 then
        skip_speed = 0
    elseif demo.SCREEN_W < 700 then
        skip_speed = 1
    elseif demo.SCREEN_W < 1000 then
        skip_speed = 2
    else
        skip_speed = 3
    end

    init_starfield_2d()

    init_asteroids()
    new_asteroid_time = 0

    --[[ introduction synced to the music --]]
    draw_intro_item(INTRO_BMP_1, 5)
    play_midi(data[GAME_MUSIC + INDEX_BASE].dat, true)
    clear_keybuf()

    if fade_intro_item(-1, 2) then
        run_game()
        return
    end

    draw_intro_item(INTRO_BMP_2, 4)
    if fade_intro_item(5, 2) then
        run_game()
        return
    end

    draw_intro_item(INTRO_BMP_3, 3)
    if fade_intro_item(9, 4) then
        run_game()
        return
    end

    draw_intro_item(INTRO_BMP_4, 2)
    if fade_intro_item(11, 4) then
        run_game()
        return
    end

    draw_intro_item(GO_BMP, 4)
    if fade_intro_item(13, 16) then
        run_game()
        return
    end

    draw_intro_item(GO_BMP, 4)
    if fade_intro_item(14, 16) then
        run_game()
        return
    end

    draw_intro_item(GO_BMP, 4)
    if fade_intro_item(15, 16) then
        run_game()
        return
    end

    draw_intro_item(GO_BMP, 4)
    if fade_intro_item(16, 16) then
        run_game()
        return
    end

    -- skip:
    run_game()
end
exports.play_game = play_game

local getters = {
    score = function() return score end,
    player_x_pos = function() return player_x_pos end,
    player_hit = function() return player_hit end,
    ship_state = function() return ship_state end,
    skip_count = function() return skip_count end,
}

local setters = {
    score = function(value) score = value end,
    player_x_pos = function(value) player_x_pos = value end,
    player_hit = function(value) player_hit = value end,
    ship_state = function(value) ship_state = value end,
    skip_count = function(value) skip_count = value end,
}

setmetatable(exports, {
    __index = function(self, key_)
        local getter = getters[key_]
        if type(getter) == "function" then
            return getter()
        end
        return nil
    end,
    __newindex = function(self, key_, value)
        local setter = setters[key_]
        if type(setter) == "function" then
            setter(value)
        else
            rawset(self, key_, value)
        end
    end
})

return exports
