local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/menu_graphics.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local defines = require("defines")
local _global = require("global")
local menu = require("menu")

local new_table = common.new_table

local DEMO_OK = defines.DEMO_OK
local DEMO_STATE_GFX = defines.DEMO_STATE_GFX
local DEMO_STATE_OPTIONS = defines.DEMO_STATE_OPTIONS

local change_gfx_mode = _global.change_gfx_mode

local DEMO_MENU = menu.DEMO_MENU
local DEMO_MENU_BACK = menu.DEMO_MENU_BACK
local DEMO_MENU_CONTINUE = menu.DEMO_MENU_CONTINUE
local DEMO_MENU_END = menu.DEMO_MENU_END
local DEMO_MENU_ITEM2 = menu.DEMO_MENU_ITEM2
local DEMO_MENU_ITEM6 = menu.DEMO_MENU_ITEM6
local DEMO_MENU_SELECTABLE = menu.DEMO_MENU_SELECTABLE

local demo_button_proc = menu.demo_button_proc
local demo_choice_proc = menu.demo_choice_proc
local demo_text_proc = menu.demo_text_proc
local draw_demo_menu = menu.draw_demo_menu
local init_demo_menu = menu.init_demo_menu
local update_demo_menu = menu.update_demo_menu

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

---@type DEMO_MENU[]
local menu ---@diagnostic disable-line: redefined-local

local _id = DEMO_STATE_GFX

local function id()
    return _id
end


local choice_on_off = { "off", "on" }
local choice_bpp = { "15 bpp", "16 bpp", "24 bpp", "32 bpp" }
local choice_res ---@type ScreenSize[]

local choice_samples = { "1x", "2x", "4x", "8x" }

local choice_fullscreen = { "window", "fullscreen window", "fullscreen" }

local function on_vsync(item)
    _global.use_vsync = item.extra
end

local function on_fullscreen(item)
    menu[3 + INDEX_BASE].flags = (function() if item.extra == 2 then return DEMO_MENU_SELECTABLE else return 0 end end)()
end

local function already(mode)
    for i = 1, #choice_res do
        if choice_res[i].width == mode.width and choice_res[i].height == mode.height then
            return true
        end
    end
    return false
end

---@class ScreenSize
---@field width integer
---@field height integer
---@overload fun(width? : integer, height? : integer): ScreenSize
local ScreenSize = common.class({
    __name = "ScreenSize",

    ---@param self ScreenSize
    ---@param width? integer
    ---@param height? integer
    __init__ = function(self, width, height)
        if width == nil then width = 0 end
        if height == nil then height = 0 end
        self.width = width
        self.height = height
    end,

    ---@param self ScreenSize
    ---@return string
    __tostring = function(self)
        return string.format("%d x %d", self.width, self.height)
    end
})

local function init()
    if not choice_res then
        local n = allegro5.al_get_num_display_modes()
        choice_res = {}
        menu[3 + INDEX_BASE].data = choice_res
        local j = 0 ---@type integer
        for i = 0, n - INDEX_BASE do
            local m = allegro5.ALLEGRO_DISPLAY_MODE()
            allegro5.al_get_display_mode(i, m)
            local mode = ScreenSize(m.width, m.height)
            if not already(mode) then
                if m.width == _global.screen_width and m.height == _global.screen_height then
                    menu[3 + INDEX_BASE].extra = j
                end
                choice_res[j + INDEX_BASE] = mode
                j = j + 1 ---@type integer
            end
        end
    end

    init_demo_menu(menu, true)

    menu[1 + INDEX_BASE].extra = _global.fullscreen

    menu[5 + INDEX_BASE].extra = _global.use_vsync

    on_fullscreen(menu[1 + INDEX_BASE])
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


local function create_gfx_menu(state)
    state.id = id
    state.init = init
    state.update = update
    state.draw = draw
end
exports.create_gfx_menu = create_gfx_menu


local function apply(item)
    local old_fullscreen = _global.fullscreen
    local old_bit_depth = _global.bit_depth
    local old_screen_width = _global.screen_width
    local old_screen_height = _global.screen_height
    local old_screen_samples = _global.screen_samples
    local old_use_vsync = _global.use_vsync

    _global.fullscreen = menu[1 + INDEX_BASE].extra

    _global.bit_depth = 0

    local mode = choice_res[menu[3 + INDEX_BASE].extra + INDEX_BASE]
    _global.screen_width = mode.width
    _global.screen_height = mode.height

    _global.screen_samples = bit.lshift(1, menu[4 + INDEX_BASE].extra)

    _global.use_vsync = menu[5 + INDEX_BASE].extra

    if _global.fullscreen == old_fullscreen and
        _global.bit_depth == old_bit_depth and
        _global.use_vsync == old_use_vsync and
        _global.screen_width == old_screen_width and
        _global.screen_height == old_screen_height and
        _global.screen_samples == old_screen_samples then
        return
    end

    if change_gfx_mode() ~= DEMO_OK then
        _global.fullscreen = old_fullscreen
        _global.bit_depth = old_bit_depth
        _global.screen_width = old_screen_width
        _global.screen_height = old_screen_height
        _global.screen_samples = old_screen_samples
        _global.use_vsync = old_use_vsync
        change_gfx_mode()
    end

    init()
end

menu = new_table(DEMO_MENU, {
    DEMO_MENU_ITEM2(demo_text_proc, "GFX SETTINGS"),
    DEMO_MENU_ITEM6(demo_choice_proc, "Mode", DEMO_MENU_SELECTABLE, 0, choice_fullscreen, on_fullscreen),
    DEMO_MENU_ITEM6(demo_choice_proc, "Bit Depth", DEMO_MENU_SELECTABLE, 0, choice_bpp, nil),
    DEMO_MENU_ITEM6(demo_choice_proc, "Screen Size", DEMO_MENU_SELECTABLE, 0, nil, nil),
    DEMO_MENU_ITEM6(demo_choice_proc, "Supersampling", DEMO_MENU_SELECTABLE, 0, choice_samples, nil),
    DEMO_MENU_ITEM6(demo_choice_proc, "Vsync", DEMO_MENU_SELECTABLE, 0, choice_on_off, on_vsync),
    DEMO_MENU_ITEM6(demo_button_proc, "Apply", DEMO_MENU_SELECTABLE, DEMO_STATE_GFX, nil, apply),
    DEMO_MENU_ITEM6(demo_button_proc, "Back", DEMO_MENU_SELECTABLE, DEMO_STATE_OPTIONS, nil, nil),
    DEMO_MENU_END
})

return exports
