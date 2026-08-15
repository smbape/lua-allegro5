local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/menu_main.c
--]]

local allegro5_lua = require("allegro5_lua")
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local defines = require("defines")
local demodata = require("demodata")
local _global = require("global")
local menu = require("menu")
local music = require("music")

local new_table = common.new_table

local DEMO_STATE_ABOUT = defines.DEMO_STATE_ABOUT
local DEMO_STATE_CONTINUE_GAME = defines.DEMO_STATE_CONTINUE_GAME
local DEMO_STATE_EXIT = defines.DEMO_STATE_EXIT
local DEMO_STATE_MAIN_MENU = defines.DEMO_STATE_MAIN_MENU
local DEMO_STATE_NEW_GAME = defines.DEMO_STATE_NEW_GAME
local DEMO_STATE_OPTIONS = defines.DEMO_STATE_OPTIONS

local DEMO_SAMPLE_WELCOME = demodata.DEMO_SAMPLE_WELCOME

local DEMO_MENU = menu.DEMO_MENU
local DEMO_MENU_BACK = menu.DEMO_MENU_BACK
local DEMO_MENU_CONTINUE = menu.DEMO_MENU_CONTINUE
local DEMO_MENU_END = menu.DEMO_MENU_END
local DEMO_MENU_ITEM4 = menu.DEMO_MENU_ITEM4
local DEMO_MENU_SELECTABLE = menu.DEMO_MENU_SELECTABLE
local DEMO_MENU_SELECTED = menu.DEMO_MENU_SELECTED

local demo_button_proc = menu.demo_button_proc
local demo_text_proc = menu.demo_text_proc
local draw_demo_menu = menu.draw_demo_menu
local init_demo_menu = menu.init_demo_menu
local update_demo_menu = menu.update_demo_menu

local play_sound = music.play_sound

local INDEX_BASE = 1 -- lua is 1-based indexed


local _id = DEMO_STATE_MAIN_MENU ---@type integer
local already_said_welcome = false

local function id()
    return _id
end


---@type DEMO_MENU[]
local menu = new_table(DEMO_MENU, { ---@diagnostic disable-line: redefined-local
    DEMO_MENU_ITEM4(demo_button_proc, "New Game", DEMO_MENU_SELECTABLE, DEMO_STATE_NEW_GAME),
    DEMO_MENU_ITEM4(demo_text_proc, "Continue Game", 0, DEMO_STATE_CONTINUE_GAME),
    DEMO_MENU_ITEM4(demo_button_proc, "Options", DEMO_MENU_SELECTABLE, DEMO_STATE_OPTIONS),
    DEMO_MENU_ITEM4(demo_button_proc, "About", DEMO_MENU_SELECTABLE, DEMO_STATE_ABOUT),
    DEMO_MENU_ITEM4(demo_button_proc, "Exit", DEMO_MENU_SELECTABLE, DEMO_STATE_EXIT),
    DEMO_MENU_END
})

local function enable_continue_game()
    menu[1 + INDEX_BASE].proc = demo_button_proc
    menu[1 + INDEX_BASE].flags = bit.bor(menu[1 + INDEX_BASE].flags, DEMO_MENU_SELECTABLE)
end
exports.enable_continue_game = enable_continue_game


local function disable_continue_game()
    menu[1 + INDEX_BASE].proc = demo_text_proc
    menu[1 + INDEX_BASE].flags = bit.band(menu[1 + INDEX_BASE].flags, bit.bnot(DEMO_MENU_SELECTABLE))

    --[[ need to move 'cursor' if it was on continue game --]]
    if bit.band(menu[1 + INDEX_BASE].flags, DEMO_MENU_SELECTED) ~= 0 then
        menu[1 + INDEX_BASE].flags = bit.band(menu[1 + INDEX_BASE].flags, bit.bnot(DEMO_MENU_SELECTED))
        menu[0 + INDEX_BASE].flags = bit.bor(menu[0 + INDEX_BASE].flags, DEMO_MENU_SELECTED)
    end
end
exports.disable_continue_game = disable_continue_game

local function init()
    init_demo_menu(menu, true)

    if not already_said_welcome then
        play_sound(_global.demo_data[DEMO_SAMPLE_WELCOME + INDEX_BASE].dat, 255, 128, 1000, false)
        already_said_welcome = true
    end
end


local function update()
    local ret = update_demo_menu(menu)


    if ret == DEMO_MENU_CONTINUE then
        return id()
    elseif ret == DEMO_MENU_BACK then
        return DEMO_STATE_EXIT
    else
        return ret
    end
end


local function draw()
    draw_demo_menu(menu)
end


local function create_main_menu(state)
    state.id = id
    state.init = init
    state.update = update
    state.draw = draw
end
exports.create_main_menu = create_main_menu

return exports
