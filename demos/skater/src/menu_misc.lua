local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/menu_misc.c
--]]

local common = require("examples.common")
local defines = require("defines")
local _global = require("global")
local menu = require("menu")

local new_table = common.new_table

local DEMO_STATE_MISC = defines.DEMO_STATE_MISC
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
local demo_text_proc = menu.demo_text_proc
local draw_demo_menu = menu.draw_demo_menu
local init_demo_menu = menu.init_demo_menu
local update_demo_menu = menu.update_demo_menu

local INDEX_BASE = 1 -- lua is 1-based indexed


local _id = DEMO_STATE_MISC

local function id()
    return _id
end


local choice_yes_no = { "no", "yes" }


---@param item DEMO_MENU
local function on_fps(item)
    _global.display_framerate = item.extra
end


---@param item DEMO_MENU
local function on_limit(item)
    _global.limit_framerate = item.extra
end


---@param item DEMO_MENU
local function on_yield(item)
    _global.reduce_cpu_usage = item.extra
end


---@type DEMO_MENU[]
local menu = new_table(DEMO_MENU, { ---@diagnostic disable-line: redefined-local
    DEMO_MENU_ITEM2(demo_text_proc, "SYSTEM SETTINGS"),
    DEMO_MENU_ITEM6(demo_choice_proc, "Show Framerate", DEMO_MENU_SELECTABLE, 0, choice_yes_no, on_fps),
    DEMO_MENU_ITEM6(demo_choice_proc, "Cap Framerate", DEMO_MENU_SELECTABLE, 0, choice_yes_no, on_limit),
    DEMO_MENU_ITEM6(demo_choice_proc, "Conserve Power", DEMO_MENU_SELECTABLE, 0, choice_yes_no, on_yield),
    DEMO_MENU_ITEM4(demo_button_proc, "Back", DEMO_MENU_SELECTABLE, DEMO_STATE_OPTIONS),
    DEMO_MENU_END
})


local function init()
    init_demo_menu(menu, true)

    menu[1 + INDEX_BASE].extra = _global.display_framerate
    menu[2 + INDEX_BASE].extra = _global.limit_framerate
    menu[3 + INDEX_BASE].extra = _global.reduce_cpu_usage
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


local function create_misc_menu(state)
    state.id = id
    state.init = init
    state.update = update
    state.draw = draw
end
exports.create_misc_menu = create_misc_menu

return exports
