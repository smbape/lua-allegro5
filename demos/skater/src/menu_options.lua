local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/menu_options.c
--]]

local common = require("examples.common")
local defines = require("defines")
local menu = require("menu")

local new_table = common.new_table

local DEMO_STATE_CONTROLS = defines.DEMO_STATE_CONTROLS
local DEMO_STATE_GFX = defines.DEMO_STATE_GFX
local DEMO_STATE_MAIN_MENU = defines.DEMO_STATE_MAIN_MENU
local DEMO_STATE_MISC = defines.DEMO_STATE_MISC
local DEMO_STATE_OPTIONS = defines.DEMO_STATE_OPTIONS
local DEMO_STATE_SOUND = defines.DEMO_STATE_SOUND

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


local _id = DEMO_STATE_OPTIONS

local function id()
    return _id
end


---@type DEMO_MENU[]
local menu = new_table(DEMO_MENU, { ---@diagnostic disable-line: redefined-local
    DEMO_MENU_ITEM2(demo_text_proc, "OPTIONS"),
    DEMO_MENU_ITEM4(demo_button_proc, "Graphics", DEMO_MENU_SELECTABLE, DEMO_STATE_GFX),
    DEMO_MENU_ITEM4(demo_button_proc, "Sound", DEMO_MENU_SELECTABLE, DEMO_STATE_SOUND),
    DEMO_MENU_ITEM4(demo_button_proc, "Controls", DEMO_MENU_SELECTABLE, DEMO_STATE_CONTROLS),
    DEMO_MENU_ITEM4(demo_button_proc, "System", DEMO_MENU_SELECTABLE, DEMO_STATE_MISC),
    DEMO_MENU_ITEM4(demo_button_proc, "Back", DEMO_MENU_SELECTABLE, DEMO_STATE_MAIN_MENU),
    DEMO_MENU_END
})


local function init()
    init_demo_menu(menu, true)
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


local function create_options_menu(state)
    state.id = id
    state.init = init
    state.update = update
    state.draw = draw
end
exports.create_options_menu = create_options_menu

return exports
