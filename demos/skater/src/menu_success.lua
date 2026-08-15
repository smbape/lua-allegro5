local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/menu_success.c
--]]

local common = require("examples.common")
local defines = require("defines")
local demodata = require("demodata")
local menu = require("menu")
local menu_main = require("menu_main")
local music = require("music")

local new_table = common.new_table

local DEMO_STATE_MAIN_MENU = defines.DEMO_STATE_MAIN_MENU
local DEMO_STATE_SUCCESS = defines.DEMO_STATE_SUCCESS

local DEMO_MIDI_SUCCESS = demodata.DEMO_MIDI_SUCCESS

local DEMO_MENU = menu.DEMO_MENU
local DEMO_MENU_BACK = menu.DEMO_MENU_BACK
local DEMO_MENU_CONTINUE = menu.DEMO_MENU_CONTINUE
local DEMO_MENU_END = menu.DEMO_MENU_END
local DEMO_MENU_ITEM2 = menu.DEMO_MENU_ITEM2
local DEMO_MENU_ITEM4 = menu.DEMO_MENU_ITEM4
local DEMO_MENU_SELECTABLE = menu.DEMO_MENU_SELECTABLE

local demo_button_proc = menu.demo_button_proc
local demo_text_proc = menu.demo_text_proc
local draw_demo_menu = menu.draw_demo_menu
local init_demo_menu = menu.init_demo_menu
local update_demo_menu = menu.update_demo_menu

local disable_continue_game = menu_main.disable_continue_game

local play_music = music.play_music

local _id = DEMO_STATE_SUCCESS

local function id()
    return _id
end


---@type DEMO_MENU[]
local menu = new_table(DEMO_MENU, { ---@diagnostic disable-line: redefined-local
    DEMO_MENU_ITEM2(demo_text_proc, "Well done! Ted's stock is saved!"),
    DEMO_MENU_ITEM2(demo_text_proc, " "),
    DEMO_MENU_ITEM2(demo_text_proc, "This demo has shown only a fraction"),
    DEMO_MENU_ITEM2(demo_text_proc, "of Allegro's capabilities."),
    DEMO_MENU_ITEM2(demo_text_proc, " "),
    DEMO_MENU_ITEM2(demo_text_proc, "Now it's up to you to show the world the rest!"),
    DEMO_MENU_ITEM2(demo_text_proc, "Get coding!"),
    DEMO_MENU_ITEM2(demo_text_proc, " "),
    DEMO_MENU_ITEM4(demo_button_proc, "Back", DEMO_MENU_SELECTABLE, DEMO_STATE_MAIN_MENU),
    DEMO_MENU_END
})


local function init()
    init_demo_menu(menu, false)
    disable_continue_game()
    play_music(DEMO_MIDI_SUCCESS, false)
end


local function update()
    local ret = update_demo_menu(menu)


    if ret == DEMO_MENU_CONTINUE then
        return id()
    elseif ret == DEMO_MENU_BACK then
        return DEMO_STATE_MAIN_MENU
    else
        return ret
    end
end


local function draw()
    draw_demo_menu(menu)
end


local function create_success_menu(state)
    state.id = id
    state.init = init
    state.update = update
    state.draw = draw
end
exports.create_success_menu = create_success_menu

return exports
