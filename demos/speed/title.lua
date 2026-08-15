local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/speed/title.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local a4_aux = require("a4_aux")
local sound = require("sound")
local speed = require("speed")

local pointer_cast = common.pointer_cast

local INDEX_BASE = 1 -- lua is 1-based indexed

local pow = math.pow or function(x, y) return x ^ y end ---@diagnostic disable-line: deprecated

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local clear_keybuf = a4_aux.clear_keybuf
local create_memory_bitmap = a4_aux.create_memory_bitmap
local create_sample_u8 = a4_aux.create_sample_u8
local hline = a4_aux.hline
local key = a4_aux.key
local keypressed = a4_aux.keypressed
local makecol = a4_aux.makecol
local poll_input_wait = a4_aux.poll_input_wait
local rectfill = a4_aux.rectfill
local replace_bitmap = a4_aux.replace_bitmap
local rest = a4_aux.rest
local retrace_count = a4_aux.retrace_count
local solid_mode = a4_aux.solid_mode
local start_retrace_count = a4_aux.start_retrace_count
local stop_retrace_count = a4_aux.stop_retrace_count
local stretch_sprite = a4_aux.stretch_sprite
local textout = a4_aux.textout
local textout_centre = a4_aux.textout_centre

local sfx_ping = sound.sfx_ping

--[[
 -    SPEED - by Shawn Hargreaves, 1999
 -
 -    Title screen and results display.
 --]]



--[[ draws text with a dropshadow --]]
local function textout_shadow(msg, x, y, c)
    textout_centre(a4_aux.font, msg, x + 1, y + 1, makecol(0, 0, 0))
    textout_centre(a4_aux.font, msg, x, y, c)
end



--[[ display the title screen --]]
local function title_screen()
    local SCREEN_W = allegro5.al_get_display_width(a4_aux.screen)
    local SCREEN_H = allegro5.al_get_display_height(a4_aux.screen)
    local white = makecol(255, 255, 255)

    local bmp = create_memory_bitmap(SCREEN_W, SCREEN_H)
    allegro5.al_set_target_bitmap(bmp)
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)

    for i = 0, math.floor(SCREEN_H / 2) - INDEX_BASE do
        hline(0, i, SCREEN_W, makecol(0, 0, math.floor(i * 255 / math.floor(SCREEN_H / 2))))
        hline(0, SCREEN_H - i - 1, SCREEN_W, makecol(0, 0, math.floor(i * 255 / math.floor(SCREEN_H / 2))))
    end

    solid_mode()

    local b = create_memory_bitmap(40, 8)
    allegro5.al_set_target_bitmap(b)
    allegro5.al_clear_to_color(allegro5.al_map_rgba(0, 0, 0, 0))

    textout(a4_aux.font, "SPEED", 0, 0, makecol(0, 0, 0))
    stretch_sprite(bmp, b, math.floor(SCREEN_W / 128) + 8, math.floor(SCREEN_H / 24) + 8, SCREEN_W, SCREEN_H)

    textout(a4_aux.font, "SPEED", 0, 0, makecol(0, 0, 64))
    stretch_sprite(bmp, b, math.floor(SCREEN_W / 128), math.floor(SCREEN_H / 24), SCREEN_W, SCREEN_H)

    allegro5.al_set_target_bitmap(bmp)

    allegro5.al_destroy_bitmap(b)

    textout_shadow("Simultaneous Projections", SCREEN_W / 2, SCREEN_H / 2 - 80, white)
    textout_shadow("Employing an Ensemble of Displays", SCREEN_W / 2, SCREEN_H / 2 - 64, white)

    textout_shadow("Or alternatively: Stupid Pointless", SCREEN_W / 2, SCREEN_H / 2 - 32, white)
    textout_shadow("Effort at Establishing a Dumb Acronym", SCREEN_W / 2, SCREEN_H / 2 - 16, white)

    textout_shadow("By Shawn Hargreaves, 1999", SCREEN_W / 2, SCREEN_H / 2 + 16, white)
    textout_shadow("Written for the Allegro", SCREEN_W / 2, SCREEN_H / 2 + 48, white)
    textout_shadow("SpeedHack competition", SCREEN_W / 2, SCREEN_H / 2 + 64, white)

    allegro5.al_set_target_bitmap(allegro5.al_get_backbuffer(a4_aux.screen))

    bmp = replace_bitmap(bmp)

    start_retrace_count()

    for i = 0, SCREEN_H / 16 do
        allegro5.al_clear_to_color(makecol(0, 0, 0))

        for j = 0, 16 do
            local y = j * math.floor(SCREEN_H / 16) ---@type integer
            allegro5.al_draw_bitmap_region(bmp, 0, y, SCREEN_W, i, 0, y, 0)
        end

        allegro5.al_flip_display()

        repeat
            poll_input_wait()
        until not (retrace_count() < i * 1024 / SCREEN_W)
    end

    stop_retrace_count()

    while a4_aux.joy_b1 or key[allegro5.ALLEGRO_KEY_SPACE] or key[allegro5.ALLEGRO_KEY_ENTER] or key[allegro5.ALLEGRO_KEY_ESCAPE] do
        poll_input_wait()
    end

    while not key[allegro5.ALLEGRO_KEY_SPACE] and not key[allegro5.ALLEGRO_KEY_ENTER] and not key[allegro5.ALLEGRO_KEY_ESCAPE] and not a4_aux.joy_b1 do
        poll_input_wait()
        allegro5.al_draw_bitmap(bmp, 0, 0, 0)
        allegro5.al_flip_display()
    end

    allegro5.al_destroy_bitmap(bmp)

    if key[allegro5.ALLEGRO_KEY_ESCAPE] then
        return false
    end

    sfx_ping(2)

    return true
end
exports.title_screen = title_screen



--[[ display the results screen --]]
local function show_results()
    local SCREEN_W = allegro5.al_get_display_width(a4_aux.screen)
    local SCREEN_H = allegro5.al_get_display_height(a4_aux.screen)

    local bmp = create_memory_bitmap(SCREEN_W, SCREEN_H)
    allegro5.al_set_target_bitmap(bmp)

    for i = 0, SCREEN_H / 2 - INDEX_BASE do
        hline(0, math.floor(SCREEN_H / 2) - i - 1, SCREEN_W, makecol(math.floor(i * 255 / math.floor(SCREEN_H / 2)), 0, 0))
        hline(0, math.floor(SCREEN_H / 2) + i, SCREEN_W, makecol(math.floor(i * 255 / math.floor(SCREEN_H / 2)), 0, 0))
    end

    local b = create_memory_bitmap(72, 8)
    allegro5.al_set_target_bitmap(b)
    allegro5.al_clear_to_color(allegro5.al_map_rgba(0, 0, 0, 0))

    textout(a4_aux.font, "GAME OVER", 0, 0, makecol(0, 0, 0))
    stretch_sprite(bmp, b, 4, math.floor(SCREEN_H / 3) + 4, SCREEN_W, math.floor(SCREEN_H / 3))

    textout(a4_aux.font, "GAME OVER", 0, 0, makecol(64, 0, 0))
    stretch_sprite(bmp, b, 0, math.floor(SCREEN_H / 3), SCREEN_W, math.floor(SCREEN_H / 3))

    allegro5.al_destroy_bitmap(b)

    allegro5.al_set_target_bitmap(bmp)
    local buf = string.format("Score: %d", speed.score)
    textout_shadow(buf, math.floor(SCREEN_W / 2), math.floor(SCREEN_H * 3 / 4), makecol(255, 255, 255))

    allegro5.al_set_target_bitmap(allegro5.al_get_backbuffer(a4_aux.screen))

    bmp = replace_bitmap(bmp)

    start_retrace_count()

    for i = 0, SCREEN_W / 16 do
        allegro5.al_clear_to_color(makecol(0, 0, 0))

        for j = 0, 16 do
            local x = j * math.floor(SCREEN_W / 16) ---@type integer
            allegro5.al_draw_bitmap_region(bmp, x, 0, i, SCREEN_H, x, 0, 0)
        end

        allegro5.al_flip_display()

        repeat
            poll_input_wait()
        until not (retrace_count() < i * 1024 / SCREEN_W)
    end

    stop_retrace_count()

    while a4_aux.joy_b1 or key[allegro5.ALLEGRO_KEY_SPACE] or key[allegro5.ALLEGRO_KEY_ENTER] or key[allegro5.ALLEGRO_KEY_ESCAPE] do
        poll_input_wait()
    end

    while not key[allegro5.ALLEGRO_KEY_SPACE] and not key[allegro5.ALLEGRO_KEY_ENTER] and not key[allegro5.ALLEGRO_KEY_ESCAPE] and not a4_aux.joy_b1 do
        poll_input_wait()
        allegro5.al_draw_bitmap(bmp, 0, 0, 0)
        allegro5.al_flip_display()
    end

    allegro5.al_destroy_bitmap(bmp)

    sfx_ping(2)
end
exports.show_results = show_results



--[[ print the shutdown message --]]
local function goodbye()
    local data1 =
    {
        0, 2, 0, 1, 2, 3, 0, 3, 5, 3, 4, 6, 0, 2, 0, 1, 2,
        3, 0, 3, 7, 3, 5, 6, 0, 2, 0, 1, 12, 3, 9, 3, 5, 3,
        4, 3, 2, 3, 10, 2, 10, 1, 9, 3, 5, 3, 7, 3, 5, 9

    }

    local data2 =
    {
        12, 3, 7, 1, 6, 1, 7, 1, 8, 3, 7, 3
    }

    local id = allegro5.ALLEGRO_SAMPLE_ID()

    if not allegro5.al_is_audio_installed() then
        allegro5.al_destroy_display(a4_aux.screen)
        a4_aux.screen = nil
        io.write("Couldn't install a digital sound driver, so no closing tune is available.\n")
        return
    end

    local s1 = create_sample_u8(44100, 256)
    local s2 = create_sample_u8(44100, 256)

    local sdata1 = pointer_cast("char", allegro5.al_get_sample_data(s1)) ---@type { [integer] : integer }
    local sdata2 = pointer_cast("char", allegro5.al_get_sample_data(s2)) ---@type { [integer] : integer }

    for i = 0, 256 - INDEX_BASE do
        sdata1[i] = i
        sdata2[i] = (function() if (i < 128) then return 255 else return 0 end end)()
    end

    local SCREEN_W = allegro5.al_get_display_width(a4_aux.screen)
    local SCREEN_H = allegro5.al_get_display_height(a4_aux.screen)

    rectfill(0, 0, math.floor(SCREEN_W / 2), math.floor(SCREEN_H / 2), makecol(255, 255, 0))
    rectfill(math.floor(SCREEN_W / 2), 0, SCREEN_W, math.floor(SCREEN_H / 2), makecol(0, 255, 0))
    rectfill(0, math.floor(SCREEN_H / 2), math.floor(SCREEN_W / 2), SCREEN_H, makecol(0, 0, 255))
    rectfill(math.floor(SCREEN_W / 2), math.floor(SCREEN_H / 2), SCREEN_W, SCREEN_H, makecol(255, 0, 0))

    local b = allegro5.al_create_bitmap(168, 8) --[[@as ALLEGRO_BITMAP --]]
    allegro5.al_set_target_bitmap(b)
    allegro5.al_clear_to_color(allegro5.al_map_rgba(0, 0, 0, 0))

    local screen_backbuffer = allegro5.al_get_backbuffer(a4_aux.screen) --[[@as ALLEGRO_BITMAP --]]

    textout(a4_aux.font, "Happy birthday Arron!", 0, 0, makecol(0, 0, 0))
    stretch_sprite(screen_backbuffer, b, math.floor(SCREEN_W / 8) + 4, math.floor(SCREEN_H * 3 / 8) + 4,
        math.floor(SCREEN_W * 3 / 4), math.floor(SCREEN_H / 4))

    textout(a4_aux.font, "Happy birthday Arron!", 0, 0, makecol(255, 255, 255))
    stretch_sprite(screen_backbuffer, b, math.floor(SCREEN_W / 8), math.floor(SCREEN_H * 3 / 8), math.floor(SCREEN_W * 3 /
    4), math.floor(SCREEN_H / 4))

    allegro5.al_set_target_bitmap(screen_backbuffer)
    allegro5.al_destroy_bitmap(b)

    allegro5.al_flip_display()

    while key[allegro5.ALLEGRO_KEY_SPACE] or key[allegro5.ALLEGRO_KEY_ENTER] or key[allegro5.ALLEGRO_KEY_ESCAPE] do
        poll_input_wait()
    end

    clear_keybuf()

    for i = 0, #data1 - INDEX_BASE * 2, 2 do
        allegro5.al_play_sample(s1, 64 / 255.0, 0.0, pow(2.0, data1[i + INDEX_BASE] / 12.0),
            allegro5.ALLEGRO_PLAYMODE_LOOP, id)
        rest(100 * data1[i + 1 + INDEX_BASE])
        allegro5.al_stop_sample(id)
        rest(50 * data1[i + 1 + INDEX_BASE])

        if keypressed() then
            return
        end
    end

    rest(500)

    allegro5.al_destroy_display(a4_aux.screen)
    a4_aux.screen = nil
    io.write("\nAnd thanks for organising this most excellent competition...\n")

    for i = 0, #data2 - INDEX_BASE * 2, 2 do
        allegro5.al_play_sample(s2, 64 / 255.0, 0.0, pow(2.0, data2[i + INDEX_BASE] / 12.0),
            allegro5.ALLEGRO_PLAYMODE_LOOP, id)
        rest(75 * data2[i + 1 + INDEX_BASE])
        allegro5.al_stop_sample(id)
        rest(25 * data2[i + 1 + INDEX_BASE])

        if keypressed() then
            return
        end
    end

    rest(300)
    io.write('\007'); io.flush()
    rest(300)
    io.write('\007'); io.flush()

    allegro5.al_stop_samples()

    allegro5.al_destroy_sample(s1)
    allegro5.al_destroy_sample(s2)
end
exports.goodbye = goodbye

return exports
