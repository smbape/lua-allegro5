local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/menu_sound.c
--]]

local common = require("examples.common")
local defines = require("defines")
local _global = require("global")
local menu = require("menu")
local music = require("music")

local new_table = common.new_table

local DEMO_STATE_OPTIONS = defines.DEMO_STATE_OPTIONS
local DEMO_STATE_SOUND = defines.DEMO_STATE_SOUND

local DEMO_MENU = menu.DEMO_MENU
local DEMO_MENU_BACK = menu.DEMO_MENU_BACK
local DEMO_MENU_CONTINUE = menu.DEMO_MENU_CONTINUE
local DEMO_MENU_END = menu.DEMO_MENU_END
local DEMO_MENU_ITEM2 = menu.DEMO_MENU_ITEM2
local DEMO_MENU_ITEM4 = menu.DEMO_MENU_ITEM4
local DEMO_MENU_ITEM6 = menu.DEMO_MENU_ITEM6
local DEMO_MENU_SELECTABLE = menu.DEMO_MENU_SELECTABLE

local demo_button_proc = menu.demo_button_proc
local demo_choice_proc = menu.demo_choice_proc
local demo_text_proc = menu.demo_text_proc
local draw_demo_menu = menu.draw_demo_menu
local init_demo_menu = menu.init_demo_menu
local update_demo_menu = menu.update_demo_menu

local set_sound_volume = music.set_sound_volume
local set_music_volume = music.set_music_volume

local INDEX_BASE = 1 -- lua is 1-based indexed

local _id = DEMO_STATE_SOUND


local function id()
    return _id
end


local choice_volume =
{ "0%%", "10%%", "20%%", "30%%", "40%%", "50%%", "60%%", "70%%",
    "80%%", "90%%", "100%%"
}


---@param item DEMO_MENU
local function on_sound(item)
    _global.sound_volume = item.extra
    set_sound_volume(_global.sound_volume / 10.0)
end


---@param item DEMO_MENU
local function on_music(item)
    _global.music_volume = item.extra
    set_music_volume(_global.music_volume / 10.0)
end


---@type DEMO_MENU[]
local menu = new_table(DEMO_MENU, { ---@diagnostic disable-line: redefined-local
    DEMO_MENU_ITEM2(demo_text_proc, "SOUND LEVELS"),
    DEMO_MENU_ITEM6(demo_choice_proc, "Sound", DEMO_MENU_SELECTABLE, 0, choice_volume, on_sound),
    DEMO_MENU_ITEM6(demo_choice_proc, "Music", DEMO_MENU_SELECTABLE, 0, choice_volume, on_music),
    DEMO_MENU_ITEM4(demo_button_proc, "Back", DEMO_MENU_SELECTABLE, DEMO_STATE_OPTIONS),
    DEMO_MENU_END
})


local function init()
    init_demo_menu(menu, true)
    menu[1 + INDEX_BASE].extra = _global.sound_volume
    menu[2 + INDEX_BASE].extra = _global.music_volume
end


local function update()
    local ret = update_demo_menu(menu)


    if ret == DEMO_MENU_CONTINUE then
        return id()
    elseif ret == DEMO_MENU_BACK then
        return DEMO_STATE_OPTIONS
    else
        return ret
    end
end


local function draw()
    draw_demo_menu(menu)
end


local function create_sound_menu(state)
    state.id = id
    state.init = init
    state.update = update
    state.draw = draw
end
exports.create_sound_menu = create_sound_menu

return exports
