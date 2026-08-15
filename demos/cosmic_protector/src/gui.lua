local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/gui.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local cosmic_protector = require("cosmic_protector")
local sound = require("sound")
local joypad_c = require("joypad_c")
local ButtonWidget = require("ButtonWidget").ButtonWidget
local Resource = require("Resource")
local ResourceManager = require("ResourceManager").ResourceManager

local new_table = common.new_table

local switch_game_in = cosmic_protector.switch_game_in
local switch_game_out = cosmic_protector.switch_game_out

local is_joypad_connected = joypad_c.is_joypad_connected
local my_play_sample = sound.my_play_sample

local RES_BACKGROUND = Resource.RES_BACKGROUND
local RES_DISPLAY = Resource.RES_DISPLAY
local RES_FIRELARGE = Resource.RES_FIRELARGE
local RES_FIRESMALL = Resource.RES_FIRESMALL
local RES_INPUT = Resource.RES_INPUT
local RES_LARGEFONT = Resource.RES_LARGEFONT
local RES_LOGO = Resource.RES_LOGO
local RES_SMALLFONT = Resource.RES_SMALLFONT

local cos = math.cos
local sin = math.sin

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/GUI.cpp
--]]

---@param widgets Widget[]
---@param selected integer
---@return integer
local function do_gui(widgets, selected)
    local rm = ResourceManager.getInstance()
    local bg = rm:getData(RES_BACKGROUND) ---@type ALLEGRO_BITMAP?
    local input = rm:getData(RES_INPUT) ---@type Input
    local logo = rm:getData(RES_LOGO) ---@type ALLEGRO_BITMAP?
    local lw = allegro5.al_get_bitmap_width(logo)
    local lh = allegro5.al_get_bitmap_height(logo)
    local myfont ---@type ALLEGRO_FONT?
    if not allegro5.ALLEGRO_IPHONE then
        myfont = rm:getData(RES_SMALLFONT) ---@type ALLEGRO_FONT?
    end

    local redraw = true

    while true do
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

        input:poll()
        local ud = 0 ---@type number
        if allegro5.ALLEGRO_IPHONE then
            if is_joypad_connected() then
                ud = input:ud()
            else
                ud = input:lr()
            end
        else
            ud = input:ud()
        end
        if ud < 0 and selected ~= 0 then
            selected = selected - 1
            my_play_sample(RES_FIRELARGE)
            allegro5.al_rest(0.200)
        elseif ud > 0 and selected < (#widgets - 1) then
            selected = selected + 1
            my_play_sample(RES_FIRELARGE)
            allegro5.al_rest(0.200)
        end
        if input:b1() then
            if not widgets[selected + INDEX_BASE]:activate() then
                return selected
            end
        end
        if not allegro5.ALLEGRO_IPHONE then
            if input:esc() then
                return -1
            end
        end

        redraw = true

        if allegro5.ALLEGRO_IPHONE then
            if cosmic_protector.switched_out then
                redraw = false
            end
        end

        allegro5.al_rest(0.010)

        if redraw then
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))

            --[[ draw --]]
            local h = allegro5.al_get_bitmap_height(bg)
            local w = allegro5.al_get_bitmap_width(bg)
            allegro5.al_draw_bitmap(bg, math.floor((cosmic_protector.BB_W - w) / 2),
                math.floor((cosmic_protector.BB_H - h) /
                    2), 0)

            allegro5.al_draw_bitmap(logo, math.floor((cosmic_protector.BB_W - lw) / 2),
                math.floor((cosmic_protector.BB_H - lh) / 4), 0)

            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
            if not allegro5.ALLEGRO_IPHONE then
                allegro5.al_draw_textf(myfont, allegro5.al_map_rgb(255, 255, 0), math.floor(cosmic_protector.BB_W / 2),
                    math.floor(cosmic_protector.BB_H / 2), allegro5.ALLEGRO_ALIGN_CENTRE, "z/y to start")
            end
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)

            for i = 0, #widgets - INDEX_BASE do
                widgets[i + INDEX_BASE]:render(i == selected)
            end

            if allegro5.ALLEGRO_IPHONE then
                input:draw()
            end

            allegro5.al_flip_display()
        end
    end
end

local function do_menu()
    local play = ButtonWidget(math.floor(cosmic_protector.BB_W / 2), math.floor(cosmic_protector.BB_H / 4) * 3 - 16, true,
        "PLAY")
    local scores = ButtonWidget(math.floor(cosmic_protector.BB_W / 2), math.floor(cosmic_protector.BB_H / 4) * 3 + 16,
        true, "SCORES")
    local _end = ButtonWidget(math.floor(cosmic_protector.BB_W / 2), math.floor(cosmic_protector.BB_H / 4) * 3 + 48, true,
        "EXIT")
    local widgets = {
        play,
        scores,
        _end,
    }
    return do_gui(widgets, 0)
end
exports.do_menu = do_menu

---@class HighScore
---@field name string
---@field score integer
---@overload fun(): HighScore
local HighScore = common.class({
    __name = "HighScore",

    ---@param self HighScore
    ---@param name? string
    ---@param score? integer
    __init__ = function(self, name, score)
        if name == nil then name = "" end
        if score == nil then score = 0 end
        self.name = name
        self.score = score
    end
})

local NUM_SCORES = 5

local highScores = new_table(HighScore, {
    { "AAA", 2000 },
    { "BAA", 1750 },
    { "AAC", 1500 },
    { "DAD", 1250 },
    { "AYE", 1000 }
})

---@param name string
---@param score integer
local function insert_score(name, score)
    local i = NUM_SCORES - 1 ---@type integer
    while i >= 0 do
        if highScores[i + INDEX_BASE].score > score then
            i = i + 1
            break
        end
        i = i - 1 ---@type integer
    end
    if i < 0 then
        i = 0
    end
    if i > (NUM_SCORES - 1) then
        return
    end -- yes, this is possible

    for j = NUM_SCORES - 1, i - INDEX_BASE * -1, -1 do
        highScores[j + INDEX_BASE].name = highScores[j - 1 + INDEX_BASE].name
        highScores[j + INDEX_BASE].score = highScores[j - 1 + INDEX_BASE].score
    end

    highScores[i + INDEX_BASE].name = name
    highScores[i + INDEX_BASE].score = score
end

local function userResourcePath()
    if allegro5.ALLEGRO_IPHONE then
        return allegro5.al_get_standard_path(allegro5.ALLEGRO_USER_DOCUMENTS_PATH)
    else
        return allegro5.al_get_standard_path(allegro5.ALLEGRO_USER_SETTINGS_PATH)
    end
end

local function read_scores()
    local fn = userResourcePath()

    if allegro5.al_make_directory(allegro5.al_path_cstr(fn, allegro5.ALLEGRO_NATIVE_PATH_SEP)) then
        allegro5.al_set_path_filename(fn, "scores.cfg")
        local cfg = allegro5.al_load_config_file(allegro5.al_path_cstr(fn, allegro5.ALLEGRO_NATIVE_PATH_SEP))
        if cfg then
            for i = 0, NUM_SCORES - INDEX_BASE do
                local name  = 'n' .. i
                local score = 's' .. i

                local v     = allegro5.al_get_config_value(cfg, "scores", name)
                if v and #v <= 3 then
                    highScores[i + INDEX_BASE].name = v
                end
                v = allegro5.al_get_config_value(cfg, "scores", score)
                if v then
                    highScores[i + INDEX_BASE].score = tonumber(v, 10)
                end
            end

            allegro5.al_destroy_config(cfg)
        end
    end

    allegro5.al_destroy_path(fn)
end

local function write_scores()
    local cfg = allegro5.al_create_config()
    for i = 0, NUM_SCORES - INDEX_BASE do
        local name  = 'n' .. i
        local score = 's' .. i

        allegro5.al_set_config_value(cfg, "scores", name, highScores[i + INDEX_BASE].name)
        local sc = string.format("%d", highScores[i + INDEX_BASE].score)
        allegro5.al_set_config_value(cfg, "scores", score, sc)
    end

    local fn = userResourcePath()
    allegro5.al_set_path_filename(fn, "scores.cfg")
    allegro5.al_save_config_file(allegro5.al_path_cstr(fn, allegro5.ALLEGRO_NATIVE_PATH_SEP), cfg)
    allegro5.al_destroy_path(fn)

    allegro5.al_destroy_config(cfg)
end

---@param score integer
local function do_highscores(score)
    read_scores()

    local rm = ResourceManager.getInstance()
    local input = rm:getData(RES_INPUT) ---@type Input
    local sm_font = rm:getData(RES_SMALLFONT) ---@type ALLEGRO_FONT?
    local big_font = rm:getData(RES_LARGEFONT) ---@type ALLEGRO_FONT?

    local is_high = score >= highScores[NUM_SCORES - 1 + INDEX_BASE].score
    local entering = is_high
    local bail_time = allegro5.al_get_time() + 8
    local letter_num = 0 ---@type integer
    local name = { " ", " ", " " } ---@type string[]
    local character = 0
    local next_input = allegro5.al_get_time()
    local spin_start = 0
    local spin_dir = 1

    local redraw = false

    while true do
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

        input:poll()

        if entering and allegro5.al_get_time() > next_input then
            local lr = input:lr()

            if lr ~= 0 then
                if lr < 0 then
                    character = character - 1
                    if character < 0 then
                        character = 25
                    end
                    spin_dir = 1
                elseif lr > 0 then
                    character = character + 1
                    if character >= 26 then
                        character = 0
                    end
                    spin_dir = -1
                end
                next_input = allegro5.al_get_time() + 0.2
                my_play_sample(RES_FIRESMALL)
                spin_start = allegro5.al_get_time()
            end

            if input:b1() and letter_num < 3 then
                name[letter_num + INDEX_BASE] = string.char(string.byte('A') + character)
                letter_num = letter_num + 1 ---@type integer
                if letter_num >= 3 then
                    entering = false
                    bail_time = allegro5.al_get_time() + 8
                    insert_score(table.concat(name), score)
                    write_scores()
                end
                next_input = allegro5.al_get_time() + 0.2
                my_play_sample(RES_FIRELARGE)
            end
        elseif not entering then
            if allegro5.al_get_time() > bail_time then
                return
            elseif (input:b1() or input:esc()) and allegro5.al_get_time() > next_input then
                allegro5.al_rest(0.250)
                return
            end
        end

        allegro5.al_rest(0.010)

        redraw = true

        if allegro5.ALLEGRO_IPHONE then
            if cosmic_protector.switched_out then
                redraw = false
            end
        end

        if redraw then
            allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))

            if entering then
                local a = allegro5.ALLEGRO_PI * 3 / 2
                local ainc = allegro5.ALLEGRO_PI * 2 / 26
                local elapsed = allegro5.al_get_time() - spin_start
                if elapsed < 0.1 then
                    a = a + ((elapsed / 0.1) * ainc * spin_dir)
                end
                local scrh = math.floor(cosmic_protector.BB_H / 2) - 32
                local h = allegro5.al_get_font_line_height(sm_font)
                for i = 0, 26 - INDEX_BASE do
                    local c = character + i ---@type integer
                    if c >= 26 then
                        c = c - (26) ---@type integer
                    end
                    local s = string.char(string.byte('A') + c)
                    local x = math.floor(math.floor(cosmic_protector.BB_W / 2) + (cos(a) * scrh) - allegro5.al_get_text_width(sm_font, s)) ---@type integer
                    local y = math.floor(math.floor(cosmic_protector.BB_H / 2) + (sin(a) * scrh) - h / 2) ---@type integer
                    allegro5.al_draw_textf(sm_font,
                        (function()
                            if i == 0 then
                                return allegro5.al_map_rgb(255, 255, 0)
                            else
                                return allegro5.al_map_rgb(200, 200, 200)
                            end
                        end)(), x, y, 0, "%s", s)
                    a = a + (ainc) ---@type number
                end
                local tmp = {} ---@type string[]
                for i = 1, #name do
                    if name[i] == " " then break end
                    tmp[i] = name[i]
                end
                allegro5.al_draw_textf(big_font, allegro5.al_map_rgb(0, 255, 0), math.floor(cosmic_protector.BB_W / 2), math.floor(cosmic_protector.BB_H / 2) - 20,
                    allegro5.ALLEGRO_ALIGN_CENTRE, "%s", table.concat(tmp))
                allegro5.al_draw_text(sm_font, allegro5.al_map_rgb(200, 200, 200), math.floor(cosmic_protector.BB_W / 2),
                    math.floor(cosmic_protector.BB_H / 2) - 20 + 5 + allegro5.al_get_font_line_height(big_font), allegro5.ALLEGRO_ALIGN_CENTRE,
                    "high score!")
            else
                local yy = math.floor(cosmic_protector.BB_H / 2) - math.floor(allegro5.al_get_font_line_height(big_font) * NUM_SCORES / 2) ---@type integer
                for i = 0, NUM_SCORES - INDEX_BASE do
                    allegro5.al_draw_textf(big_font, allegro5.al_map_rgb(255, 255, 255), math.floor(cosmic_protector.BB_W / 2) - 10, yy,
                        allegro5.ALLEGRO_ALIGN_RIGHT, "%s", highScores[i + INDEX_BASE].name)
                    allegro5.al_draw_text(big_font, allegro5.al_map_rgb(255, 255, 0), math.floor(cosmic_protector.BB_W / 2) + 10, yy,
                        allegro5.ALLEGRO_ALIGN_LEFT, string.format("%d", highScores[i + INDEX_BASE].score))
                    yy = yy + allegro5.al_get_font_line_height(big_font) ---@type integer
                end
            end

            if allegro5.ALLEGRO_IPHONE then
                input:draw()
            end

            allegro5.al_flip_display()
        end
    end
end
exports.do_highscores = do_highscores

return exports
