local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/intro.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local defines = require("defines")
local demodata = require("demodata")
local _global = require("global")
local keyboard = require("keyboard")
local mouse = require("mouse")
local music = require("music")

local DEMO_STATE_INTRO = defines.DEMO_STATE_INTRO
local DEMO_STATE_MAIN_MENU = defines.DEMO_STATE_MAIN_MENU

local DEMO_MIDI_INTRO = demodata.DEMO_MIDI_INTRO

local demo_textprintf_centre = _global.demo_textprintf_centre

local key_pressed = keyboard.key_pressed

local mouse_button_pressed = mouse.mouse_button_pressed

local play_music = music.play_music

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local _id = DEMO_STATE_INTRO ---@type integer
local duration = 0 ---@type number
local progress = 0 ---@type number
local already_played_midi = false ---@type boolean

---@return integer
local function id()
    return _id
end


local function init()
    duration = 4.0
    progress = 0.0
    already_played_midi = false
end


---@return integer
local function update()
    progress = progress + (1.0 / _global.logic_framerate)

    if progress >= duration then
        return DEMO_STATE_MAIN_MENU
    end

    if key_pressed(allegro5.ALLEGRO_KEY_ESCAPE) then
        return DEMO_STATE_MAIN_MENU
    end
    if key_pressed(allegro5.ALLEGRO_KEY_SPACE) then
        return DEMO_STATE_MAIN_MENU
    end
    if key_pressed(allegro5.ALLEGRO_KEY_ENTER) then
        return DEMO_STATE_MAIN_MENU
    end
    if mouse_button_pressed(1) then
        return DEMO_STATE_MAIN_MENU
    end

    return id()
end


local function draw()
    local logo_text1 = "Allegro"
    local logo_text2 = ""
    --[[ XXX commented out because the font doesn't contain the characters for
    - anything other than "Allegro 4.2"
    --]]
    --[[ static char logo_text2[] = "5.0"; --]]

    if progress < 0.5 then
        local c = progress / 0.5
        allegro5.al_clear_to_color(allegro5.al_map_rgb_f(c, c, c))
    else
        if not already_played_midi then
            play_music(DEMO_MIDI_INTRO, false)
            already_played_midi = true
        end

        local c = 1 ---@type number
        allegro5.al_clear_to_color(allegro5.al_map_rgb_f(c, c, c))

        local x = math.floor(_global.screen_width / 2) ---@type integer
        local y = math.floor(_global.screen_height / 2) - math.floor(3 * allegro5.al_get_font_line_height(_global.demo_font_logo) / 2) ---@type integer

        local offx = 0 ---@type integer
        if progress < 1.0 then
            offx =
                math.floor(allegro5.al_get_text_width(_global.demo_font_logo, logo_text1) *
                    (1.0 - 2.0 * (progress - 0.5)))
        end

        demo_textprintf_centre(_global.demo_font_logo, x + 6 - offx,
            y + 5, allegro5.al_map_rgba_f(0.125, 0.125, 0.125, 0.25), logo_text1)
        demo_textprintf_centre(_global.demo_font_logo, x - offx, y,
            allegro5.al_map_rgba_f(1, 1, 1, 1), logo_text1)

        if progress >= 1.5 then
            y = y + 3 * math.floor(allegro5.al_get_font_line_height(_global.demo_font_logo) / 2) ---@type integer
            local offy = 0
            if progress < 2.0 then
                offy = math.floor((_global.screen_height - y) * (1.0 - 2.0 * (progress - 1.5)))
            end

            demo_textprintf_centre(_global.demo_font_logo, x + 6,
                y + 5 + offy, allegro5.al_map_rgba_f(0.125, 0.125, 0.125, 0.25),
                logo_text2)
            demo_textprintf_centre(_global.demo_font_logo, x, y + offy,
                allegro5.al_map_rgba_f(1, 1, 1, 1), logo_text2)
        end
    end
end


local function create_intro(state)
    state.id = id
    state.init = init
    state.update = update
    state.draw = draw
end
exports.create_intro = create_intro

return exports
