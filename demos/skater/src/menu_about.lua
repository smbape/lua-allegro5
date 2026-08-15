local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/menu_about.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local defines = require("defines")
local menu = require("menu")

local new_table = common.new_table

local DEMO_STATE_ABOUT = defines.DEMO_STATE_ABOUT
local DEMO_STATE_MAIN_MENU = defines.DEMO_STATE_MAIN_MENU

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

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end


local _id = DEMO_STATE_ABOUT

---@return integer
local function id()
    return _id
end


---@type DEMO_MENU[]
local menu = new_table(DEMO_MENU, { ---@diagnostic disable-line: redefined-local
    DEMO_MENU_ITEM2(demo_text_proc, "Looks like rain. And soon!"),
    DEMO_MENU_ITEM2(demo_text_proc, " "),
    DEMO_MENU_ITEM2(demo_text_proc, "Help coastal outdoor confectioner Ted collect the cherries,"),
    DEMO_MENU_ITEM2(demo_text_proc, "bananas, sliced oranges, sweets and ice creams he has on display"),
    DEMO_MENU_ITEM2(demo_text_proc, "before the rain begins!"),
    DEMO_MENU_ITEM2(demo_text_proc, "Luckily he has a skateboard so it should be a breeze!"),
    DEMO_MENU_ITEM2(demo_text_proc, " "),
    DEMO_MENU_ITEM2(demo_text_proc, nil),
    DEMO_MENU_ITEM2(demo_text_proc, "by Shawn Hargreaves and many others"),
    DEMO_MENU_ITEM2(demo_text_proc, " "),
    DEMO_MENU_ITEM2(demo_text_proc, "Allegro Demo Game"),
    DEMO_MENU_ITEM2(demo_text_proc, "By Miran Amon, Nick Davies, Elias Pschernig, Thomas Harte & Jakub Wasilewski"),
    DEMO_MENU_ITEM2(demo_text_proc, " "),
    DEMO_MENU_ITEM4(demo_button_proc, "Back", DEMO_MENU_SELECTABLE, DEMO_STATE_MAIN_MENU),
    DEMO_MENU_END
})


local function init()
    local v = allegro5.al_get_allegro_version()
    menu[7 + INDEX_BASE].name = string.format("Allegro %d.%d.%d", bit.rshift(v, 24), bit.band(bit.rshift(v, 16), 255),
        bit.band(bit.rshift(v, 8), 255))
    init_demo_menu(menu, true)
end


---@return integer
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

---@param state GAMESTATE
local function create_about_menu(state)
    state.id = id
    state.init = init
    state.update = update
    state.draw = draw
end
exports.create_about_menu = create_about_menu

return exports
