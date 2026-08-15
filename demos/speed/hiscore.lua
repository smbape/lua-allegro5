local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/speed/hiscore.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local a4_aux = require("a4_aux")
local sound = require("sound")
local speed = require("speed")

local new_table = common.new_table

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local clear_keybuf = a4_aux.clear_keybuf
local create_memory_bitmap = a4_aux.create_memory_bitmap
local get_config_int = a4_aux.get_config_int
local get_config_string = a4_aux.get_config_string
local hline = a4_aux.hline
local key = a4_aux.key
local keypressed = a4_aux.keypressed
local makecol = a4_aux.makecol
local poll_input_wait = a4_aux.poll_input_wait
local readkey = a4_aux.readkey
local rectfill = a4_aux.rectfill
local replace_bitmap = a4_aux.replace_bitmap
local retrace_count = a4_aux.retrace_count
local set_config_int = a4_aux.set_config_int
local start_retrace_count = a4_aux.start_retrace_count
local stop_retrace_count = a4_aux.stop_retrace_count
local stretch_sprite = a4_aux.stretch_sprite
local textout = a4_aux.textout
local textprintf = a4_aux.textprintf
local vline = a4_aux.vline

local sfx_explode_alien = sound.sfx_explode_alien
local sfx_explode_player = sound.sfx_explode_player
local sfx_ping = sound.sfx_ping
local sfx_shoot = sound.sfx_shoot

--[[
 -    SPEED - by Shawn Hargreaves, 1999
 -
 -    Hiscore table.
 --]]


local NUM_SCORES = 8
local MAX_NAME_LEN = 24


--[[ the score table --]]
---@type integer[]
local scores =
{
    666, 512, 440, 256, 192, 128, 64, 42
}

local names = new_table("", NUM_SCORES) ---@type string[]

local yourname = "" ---@type string



--[[ initialises the hiscore system --]]
local function init_hiscore()
    local path = allegro5.al_get_standard_path(allegro5.ALLEGRO_USER_DATA_PATH)
    if not path then
        return
    end
    allegro5.al_make_directory(allegro5.al_path_cstr(path, allegro5.ALLEGRO_NATIVE_PATH_SEP))

    allegro5.al_set_path_filename(path, "speed.rec")

    local cfg = allegro5.al_load_config_file(allegro5.al_path_cstr(path, allegro5.ALLEGRO_NATIVE_PATH_SEP))
    if not cfg then
        cfg = allegro5.al_create_config() --[[@as ALLEGRO_CONFIG]]
    end

    for i = 0, NUM_SCORES - INDEX_BASE do
        local buf1 = string.format("score%d", i + 1)
        scores[i + INDEX_BASE] = get_config_int(cfg, "hiscore", buf1, scores[i + INDEX_BASE])

        buf1 = string.format("name%d", i + 1)
        names[i + INDEX_BASE] = get_config_string(cfg, "hiscore", buf1, "Shawn Hargreaves")
    end

    allegro5.al_destroy_config(cfg)
    allegro5.al_destroy_path(path)
end
exports.init_hiscore = init_hiscore



--[[ shuts down the hiscore system --]]
local function shutdown_hiscore()
    local path = allegro5.al_get_standard_path(allegro5.ALLEGRO_USER_DATA_PATH)
    if not path then
        return
    end
    allegro5.al_make_directory(allegro5.al_path_cstr(path, allegro5.ALLEGRO_NATIVE_PATH_SEP))

    allegro5.al_set_path_filename(path, "speed.rec")

    local cfg = allegro5.al_create_config() --[[@as ALLEGRO_CONFIG]]

    for i = 0, NUM_SCORES - INDEX_BASE do
        local buf1 = string.format("score%d", i + 1)
        set_config_int(cfg, "hiscore", buf1, scores[i + INDEX_BASE])

        buf1 = string.format("name%d", i + 1)
        allegro5.al_set_config_value(cfg, "hiscore", buf1, names[i + INDEX_BASE])
    end

    allegro5.al_save_config_file(allegro5.al_path_cstr(path, allegro5.ALLEGRO_NATIVE_PATH_SEP), cfg)

    allegro5.al_destroy_config(cfg)
    allegro5.al_destroy_path(path)
end
exports.shutdown_hiscore = shutdown_hiscore



--[[ displays the text entry box --]]
---@param which integer
---@param retrace_count_ integer
local function draw_entry_box(which, retrace_count_)
    local w = MAX_NAME_LEN * 8 + 16 ---@type integer
    local h = 16 ---@type integer

    local screen = allegro5.al_get_target_bitmap()
    local SCREEN_W = allegro5.al_get_bitmap_width(screen)
    local SCREEN_H = allegro5.al_get_bitmap_height(screen)

    local b = create_memory_bitmap(w, h)
    allegro5.al_set_target_bitmap(b)
    allegro5.al_clear_to_color(makecol(0, 96, 0))
    hline(0, w, h - 1, makecol(0, 32, 0))
    vline(0, w - 1, h, makecol(0, 32, 0))

    textprintf(a4_aux.font, 9, 5, makecol(0, 0, 0), "%s", yourname)
    textprintf(a4_aux.font, 8, 4, makecol(255, 255, 255), "%s", yourname)

    if bit.band(retrace_count_, 8) ~= 0 then
        local x = #yourname * 8 + 8 ---@type integer
        rectfill(x, 12, x + 7, 14, makecol(0, 0, 0))
    end

    allegro5.al_set_target_bitmap(screen)
    allegro5.al_draw_bitmap(b, math.floor(SCREEN_W / 2) - 56, math.floor(SCREEN_H / 2) + (which - math.floor(NUM_SCORES / 2)) * 16 - 4, 0)

    allegro5.al_destroy_bitmap(b)
end



--[[ displays the score table --]]
local function score_table()
    local SCREEN_W = allegro5.al_get_display_width(a4_aux.screen)
    local SCREEN_H = allegro5.al_get_display_height(a4_aux.screen)
    -- local bmp, b = nil, nil
    -- local col = allegro5.ALLEGRO_COLOR()
    local myscore = -1 ---@type integer

    for i = 0, NUM_SCORES - INDEX_BASE do
        if speed.score > scores[i + INDEX_BASE] then
            for j = NUM_SCORES - 1, i - INDEX_BASE * -1, -1 do
                scores[j + INDEX_BASE] = scores[j - 1 + INDEX_BASE]
                names[j + INDEX_BASE] = names[j - 1 + INDEX_BASE]
            end

            scores[i + INDEX_BASE] = speed.score
            names[i + INDEX_BASE] = yourname

            myscore = i
            break
        end
    end

    local bmp = create_memory_bitmap(SCREEN_W, SCREEN_H)
    allegro5.al_set_target_bitmap(bmp)

    for i = 0, math.floor(SCREEN_W / 2) - INDEX_BASE do
        vline(math.floor(SCREEN_W / 2) - i - 1, 0, SCREEN_H, makecol(0, math.floor(i * 255 / math.floor(SCREEN_W / 2)), 0))
        vline(math.floor(SCREEN_W / 2) + i, 0, SCREEN_H, makecol(0, math.floor(i * 255 / math.floor(SCREEN_W / 2)), 0))
    end

    local b = create_memory_bitmap(104, 8)
    allegro5.al_set_target_bitmap(b)
    allegro5.al_clear_to_color(allegro5.al_map_rgba(0, 0, 0, 0))

    textout(a4_aux.font, "HISCORE TABLE", 0, 0, makecol(0, 0, 0))
    stretch_sprite(bmp, b, math.floor(SCREEN_W / 64) + 4, math.floor(SCREEN_H / 64) + 4, math.floor(SCREEN_W * 31 / 32), math.floor(SCREEN_H / 8))
    stretch_sprite(bmp, b, math.floor(SCREEN_W / 64) + 4, math.floor(SCREEN_H * 55 / 64) + 4, math.floor(SCREEN_W * 31 / 32), math.floor(SCREEN_H / 8))

    textout(a4_aux.font, "HISCORE TABLE", 0, 0, makecol(0, 64, 0))
    stretch_sprite(bmp, b, math.floor(SCREEN_W / 64), math.floor(SCREEN_H / 64), math.floor(SCREEN_W * 31 / 32), math.floor(SCREEN_H / 8))
    stretch_sprite(bmp, b, math.floor(SCREEN_W / 64), math.floor(SCREEN_H * 55 / 64), math.floor(SCREEN_W * 31 / 32), math.floor(SCREEN_H / 8))

    allegro5.al_destroy_bitmap(b)
    allegro5.al_set_target_bitmap(bmp)

    for i = 0, NUM_SCORES - INDEX_BASE do
        local y = math.floor(SCREEN_H / 2) + (i - math.floor(NUM_SCORES / 2)) * 16 ---@type integer

        textprintf(a4_aux.font, math.floor(SCREEN_W / 2) - 142, y + 2, makecol(0, 0, 0), "#%d - %d", i + 1, scores[i + INDEX_BASE])
        textprintf(a4_aux.font, math.floor(SCREEN_W / 2) - 47, y + 1, makecol(0, 0, 0), "%s", names[i + INDEX_BASE])

        local col ---@type ALLEGRO_COLOR
        if i == myscore then
            col = makecol(255, 0, 0)
        else
            col = makecol(255, 255, 255)
        end

        textprintf(a4_aux.font, math.floor(SCREEN_W / 2) - 144, y, col, "#%d - %d", i + 1, scores[i + INDEX_BASE])
        textprintf(a4_aux.font, math.floor(SCREEN_W / 2) - 48, y, col, "%s", names[i + INDEX_BASE])
    end

    if myscore >= 0 then
        draw_entry_box(myscore, 0)
    end

    bmp = replace_bitmap(bmp)

    allegro5.al_set_target_bitmap(allegro5.al_get_backbuffer(a4_aux.screen))

    start_retrace_count()

    for i = 0, SCREEN_H / 16 do
        allegro5.al_clear_to_color(makecol(0, 0, 0))

        for j = 0, 16 do
            local x = j * math.floor(SCREEN_W / 16) ---@type integer
            allegro5.al_draw_bitmap_region(bmp, x, 0, i, SCREEN_H, x, 0, 0)

            local y = j * math.floor(SCREEN_H / 16) ---@type integer
            allegro5.al_draw_bitmap_region(bmp, 0, y, SCREEN_W, i, 0, y, 0)
        end

        allegro5.al_flip_display()

        repeat
            poll_input_wait()
        until not (retrace_count() < i * 512 / SCREEN_W)
    end

    while a4_aux.joy_b1 or key[allegro5.ALLEGRO_KEY_SPACE] or key[allegro5.ALLEGRO_KEY_ENTER] or key[allegro5.ALLEGRO_KEY_ESCAPE] do
        poll_input_wait()
    end

    if myscore >= 0 then
        clear_keybuf()

        while true do
            poll_input_wait()

            if (a4_aux.joy_b1) and #yourname ~= 0 then
                names[myscore + INDEX_BASE] = yourname
                break
            end

            if keypressed() then
                local c = readkey() ---@type integer

                if (bit.rshift(c, 8) == allegro5.ALLEGRO_KEY_ENTER) and #yourname ~= 0 then
                    names[myscore + INDEX_BASE] = yourname
                    sfx_explode_player()
                    break
                elseif (bit.rshift(c, 8) == allegro5.ALLEGRO_KEY_ESCAPE) and (names[myscore + INDEX_BASE][0]) then
                    yourname = names[myscore + INDEX_BASE]
                    sfx_ping(2)
                    break
                elseif (bit.rshift(c, 8) == allegro5.ALLEGRO_KEY_BACKSPACE) and (#yourname > 0) then
                    yourname = yourname:sub(1, #yourname - 1) ---@type string
                    sfx_shoot()
                elseif (bit.band(c, 0xFF) >= string.byte(' ')) and (bit.band(c, 0xFF) <= string.byte('~')) and (#yourname < MAX_NAME_LEN) then
                    yourname = yourname .. string.char(bit.band(c, 0xFF))
                    sfx_explode_alien()
                end
            end

            allegro5.al_draw_bitmap(bmp, 0, 0, 0)
            draw_entry_box(myscore, retrace_count())
            allegro5.al_flip_display()
        end
    else
        while not key[allegro5.ALLEGRO_KEY_SPACE] and not key[allegro5.ALLEGRO_KEY_ENTER] and not key[allegro5.ALLEGRO_KEY_ESCAPE] and not a4_aux.joy_b1 do
            poll_input_wait()
            allegro5.al_draw_bitmap(bmp, 0, 0, 0)
            allegro5.al_flip_display()
        end

        sfx_ping(2)
    end

    stop_retrace_count()

    allegro5.al_destroy_bitmap(bmp)
end
exports.score_table = score_table



--[[ returns the best score, for other modules to display --]]
local function get_hiscore()
    return scores[0 + INDEX_BASE]
end
exports.get_hiscore = get_hiscore

return exports
