local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/menu_controls.c
--]]

local common = require("examples.common")
local defines = require("defines")
local _global = require("global")
local menu = require("menu")

local new_table = common.new_table

local DEMO_BUTTON_JUMP = defines.DEMO_BUTTON_JUMP
local DEMO_BUTTON_LEFT = defines.DEMO_BUTTON_LEFT
local DEMO_BUTTON_RIGHT = defines.DEMO_BUTTON_RIGHT
local DEMO_STATE_CONTROLS = defines.DEMO_STATE_CONTROLS
local DEMO_STATE_OPTIONS = defines.DEMO_STATE_OPTIONS

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
local demo_key_proc = menu.demo_key_proc
local demo_text_proc = menu.demo_text_proc
local draw_demo_menu = menu.draw_demo_menu
local init_demo_menu = menu.init_demo_menu
local update_demo_menu = menu.update_demo_menu

local INDEX_BASE = 1 -- lua is 1-based indexed


local _id = DEMO_STATE_CONTROLS

---@return integer
local function id()
    return _id
end


local choice_controls = { "keyboard", "gamepad" }


---@param item DEMO_MENU
local function on_controller(item)
    _global.controller_id = item.extra
end


---@type DEMO_MENU[]
local menu = new_table(DEMO_MENU, { ---@diagnostic disable-line: redefined-local
    DEMO_MENU_ITEM2(demo_text_proc, "SETUP CONTROLS"),
    DEMO_MENU_ITEM6(demo_choice_proc, "Controller", DEMO_MENU_SELECTABLE, 0, choice_controls, on_controller),
    DEMO_MENU_ITEM4(demo_key_proc, "Left", DEMO_MENU_SELECTABLE, DEMO_BUTTON_LEFT),
    DEMO_MENU_ITEM4(demo_key_proc, "Right", DEMO_MENU_SELECTABLE, DEMO_BUTTON_RIGHT),
    DEMO_MENU_ITEM4(demo_key_proc, "Jump", DEMO_MENU_SELECTABLE, DEMO_BUTTON_JUMP),
    DEMO_MENU_ITEM4(demo_button_proc, "Back", DEMO_MENU_SELECTABLE, DEMO_STATE_OPTIONS),
    DEMO_MENU_END
})


local function init()
    init_demo_menu(menu, true)

    menu[1 + INDEX_BASE].extra = _global.controller_id
end


---@return integer
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


local function create_controls_menu(state)
    state.id = id
    state.init = init
    state.update = update
    state.draw = draw
end
exports.create_controls_menu = create_controls_menu


return exports
