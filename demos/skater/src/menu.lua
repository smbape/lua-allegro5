local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/menu.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local background_scroller = require("background_scroller")
local credits = require("credits")
local common = require("examples.common")
local demodata = require("demodata")
local gamepad = require("gamepad")
local _global = require("global")
local keyboard = require("keyboard")
local mouse = require("mouse")
local music = require("music")

local draw_background = background_scroller.draw_background
local update_background = background_scroller.update_background

local draw_credits = credits.draw_credits
local update_credits = credits.update_credits

local DEMO_MIDI_MENU = demodata.DEMO_MIDI_MENU
local DEMO_SAMPLE_BUTTON = demodata.DEMO_SAMPLE_BUTTON

local gamepad_button = gamepad.gamepad_button

local controller = _global.controller
local demo_textprintf_centre = _global.demo_textprintf_centre
local shadow_textprintf = _global.shadow_textprintf

local key_down = keyboard.key_down
local key_pressed = keyboard.key_pressed
local unicode_char = keyboard.unicode_char

local mouse_button_pressed = mouse.mouse_button_pressed
local mouse_x = mouse.mouse_x
local mouse_y = mouse.mouse_y

local play_music = music.play_music
local play_sound_id = music.play_sound_id

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end


local DEMO_MENU_CONTINUE = 1000
exports.DEMO_MENU_CONTINUE = DEMO_MENU_CONTINUE

local DEMO_MENU_BACK = 1001
exports.DEMO_MENU_BACK = DEMO_MENU_BACK

local DEMO_MENU_LOCK = 1002
exports.DEMO_MENU_LOCK = DEMO_MENU_LOCK


local DEMO_MENU_SELECTABLE = 1
exports.DEMO_MENU_SELECTABLE = DEMO_MENU_SELECTABLE

local DEMO_MENU_SELECTED = 2
exports.DEMO_MENU_SELECTED = DEMO_MENU_SELECTED

local DEMO_MENU_EXIT = 4
exports.DEMO_MENU_EXIT = DEMO_MENU_EXIT

local DEMO_MENU_EXTRA = 8
exports.DEMO_MENU_EXTRA = DEMO_MENU_EXTRA


local DEMO_MENU_MSG_INIT = 0
exports.DEMO_MENU_MSG_INIT = DEMO_MENU_MSG_INIT

local DEMO_MENU_MSG_DRAW = 1
exports.DEMO_MENU_MSG_DRAW = DEMO_MENU_MSG_DRAW

local DEMO_MENU_MSG_CHAR = 2
exports.DEMO_MENU_MSG_CHAR = DEMO_MENU_MSG_CHAR

local DEMO_MENU_MSG_KEY = 3
exports.DEMO_MENU_MSG_KEY = DEMO_MENU_MSG_KEY

local DEMO_MENU_MSG_WIDTH = 4
exports.DEMO_MENU_MSG_WIDTH = DEMO_MENU_MSG_WIDTH

local DEMO_MENU_MSG_HEIGHT = 5
exports.DEMO_MENU_MSG_HEIGHT = DEMO_MENU_MSG_HEIGHT

local DEMO_MENU_MSG_TICK = 6
exports.DEMO_MENU_MSG_TICK = DEMO_MENU_MSG_TICK



---@class DEMO_MENU
---@field proc? fun(menu : DEMO_MENU, type : integer, value : integer) : integer
---@field name? string
---@field flags integer
---@field extra integer
---@field data? table
---@field on_activate? function
---@field x integer
---@field y integer
---@field w integer
---@field h integer
---@overload fun(proc? : function, name? : string, flags? : integer, extra? : integer, data? : table, on_activate? : function, x? : integer, y? : integer, w? : integer, h? : integer): DEMO_MENU
local DEMO_MENU = common.class({
    __name = "DEMO_MENU",

    ---@param self DEMO_MENU
    ---@param proc? fun(menu : DEMO_MENU, type : integer, value : integer) : integer
    ---@param name? string
    ---@param flags? integer
    ---@param extra? integer
    ---@param data? table
    ---@param on_activate? function
    ---@param x? integer
    ---@param y? integer
    ---@param w? integer
    ---@param h? integer
    __init__ = function(self, proc, name, flags, extra, data, on_activate, x, y, w, h)
        if proc == 0 then proc = nil end
        if name == 0 then name = nil end
        if flags == nil then flags = 0 end
        if extra == nil then extra = 0 end
        if data == 0 then data = nil end
        if on_activate == 0 then on_activate = nil end
        if x == nil then x = 0 end
        if y == nil then y = 0 end
        if w == nil then w = 0 end
        if h == nil then h = 0 end
        self.proc = proc
        self.name = name
        self.flags = flags
        self.extra = extra
        self.data = data
        self.on_activate = on_activate
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    end
})
exports.DEMO_MENU = DEMO_MENU

---@param proc? function
---@param name? string
---@return [function?, string?, integer?, integer?, table?, function?, integer?, integer?, integer?, integer?]
local function DEMO_MENU_ITEM2(proc, name)
    return { proc, name, 0, 0, 0, 0, 0, 0, 0, 0 }
end
exports.DEMO_MENU_ITEM2 = DEMO_MENU_ITEM2

---@param proc? function
---@param name? string
---@param flags integer
---@param extra integer
---@return [function?, string?, integer?, integer?, table?, function?, integer?, integer?, integer?, integer?]
local function DEMO_MENU_ITEM4(proc, name, flags, extra)
    return { proc, name, flags, extra, 0, 0, 0, 0, 0, 0 }
end
exports.DEMO_MENU_ITEM4 = DEMO_MENU_ITEM4

---@param proc? function
---@param name? string
---@param flags integer
---@param extra integer
---@param data? table
---@param on_activate? function
---@return [function?, string?, integer?, integer?, table?, function?, integer?, integer?, integer?, integer?]
local function DEMO_MENU_ITEM6(proc, name, flags, extra, data, on_activate)
    return { proc, name, flags, extra, data, on_activate, 0, 0, 0, 0 }
end
exports.DEMO_MENU_ITEM6 = DEMO_MENU_ITEM6

local DEMO_MENU_END = DEMO_MENU_ITEM2(nil, nil)
exports.DEMO_MENU_END = DEMO_MENU_END

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/menu.c
--]]

---@param x integer
---@param y integer
---@return integer
local function MIN(x, y)
    if x < y then return x end
    return y
end

---@param x integer
---@param y integer
---@return integer
local function MAX(x, y)
    if x > y then return x end
    return y
end

local selected_item = 0 ---@type integer
local item_count = 0 ---@type integer
local locked = false ---@type boolean
local freq_variation = 100 ---@type integer

---@param menu DEMO_MENU[]
---@param PlayMusic boolean
local function init_demo_menu(menu, PlayMusic)
    selected_item = -1
    item_count = #menu
    locked = false

    for _, item in ipairs(menu) do
        if not item.proc then
            break
        end
        item.proc(item, DEMO_MENU_MSG_INIT, 0)
    end

    for i, item in ipairs(menu) do
        if bit.band(item.flags, DEMO_MENU_SELECTED) ~= 0 then
            selected_item = i - INDEX_BASE
            break
        end
    end

    if selected_item == -1 then
        for i, item in ipairs(menu) do
            if bit.band(item.flags, DEMO_MENU_SELECTABLE) ~= 0 then
                selected_item = i - INDEX_BASE
                item.flags = bit.bor(item.flags, DEMO_MENU_SELECTED)
                break
            end
        end
    end

    if PlayMusic then
        play_music(DEMO_MIDI_MENU, true)
    end
end
exports.init_demo_menu = init_demo_menu


---@param menu DEMO_MENU[]
---@return integer
local function update_demo_menu(menu)
    update_background()
    update_credits()

    if selected_item ~= -1 then
        menu[selected_item + INDEX_BASE].proc(menu[selected_item + INDEX_BASE], DEMO_MENU_MSG_KEY, 0)
    end

    for _, item in ipairs(menu) do
        if not item.proc then
            break
        end
        if item.proc(item, DEMO_MENU_MSG_TICK, 0) == DEMO_MENU_LOCK then
            locked = false
            return DEMO_MENU_CONTINUE
        end
    end

    if locked then
        return DEMO_MENU_CONTINUE
    end

    if key_pressed(allegro5.ALLEGRO_KEY_ESCAPE) then
        return DEMO_MENU_BACK
    end

    --[[ If a mouse button is pressed, select the item under it and send a
    - DEMO_MENU_MSG_CHAR with 13 to it (which is the same effect as hitting
    - the return key).
    --]]
    if mouse_button_pressed(1) then
        for i, item in ipairs(menu) do
            if mouse_x() >= item.x and mouse_y() >= item.y and
                mouse_x() < item.x + item.w and
                mouse_y() < item.y + item.h then
                if bit.band(item.flags, DEMO_MENU_SELECTABLE) ~= 0 then
                    if selected_item ~= -1 then
                        menu[selected_item + INDEX_BASE].flags = bit.band(menu[selected_item + INDEX_BASE].flags,
                            bit.bnot(DEMO_MENU_SELECTED))
                    end
                    selected_item = i - INDEX_BASE
                    item.flags = bit.bor(item.flags, DEMO_MENU_SELECTED)
                    play_sound_id(DEMO_SAMPLE_BUTTON, 255, 128, -freq_variation, false)
                    return item.proc(item, DEMO_MENU_MSG_CHAR, 13)
                end
            end
        end
    end

    if key_pressed(allegro5.ALLEGRO_KEY_UP) then
        if selected_item ~= -1 then
            local tmp = selected_item ---@type integer

            while 1 do
                selected_item = selected_item - 1
                if selected_item < 0 then
                    selected_item = item_count - 1
                end

                if bit.band(menu[selected_item + INDEX_BASE].flags, DEMO_MENU_SELECTABLE) ~= 0 then
                    break
                end
            end

            if tmp ~= selected_item then
                menu[tmp + INDEX_BASE].flags = bit.band(menu[tmp + INDEX_BASE].flags, bit.bnot(DEMO_MENU_SELECTED))
                menu[selected_item + INDEX_BASE].flags = bit.bor(menu[selected_item + INDEX_BASE].flags,
                    DEMO_MENU_SELECTED)
                play_sound_id(DEMO_SAMPLE_BUTTON, 255, 128, -freq_variation, false)
            end
        end
    end

    if key_pressed(allegro5.ALLEGRO_KEY_DOWN) then
        if selected_item ~= -1 then
            local tmp = selected_item

            while 1 do
                selected_item = selected_item + 1
                if selected_item >= item_count then
                    selected_item = 0
                end

                if bit.band(menu[selected_item + INDEX_BASE].flags, DEMO_MENU_SELECTABLE) ~= 0 then
                    break
                end
            end

            if tmp ~= selected_item then
                menu[tmp + INDEX_BASE].flags = bit.band(menu[tmp + INDEX_BASE].flags, bit.bnot(DEMO_MENU_SELECTED))
                menu[selected_item + INDEX_BASE].flags = bit.bor(menu[selected_item + INDEX_BASE].flags,
                    DEMO_MENU_SELECTED)
                play_sound_id(DEMO_SAMPLE_BUTTON, 255, 128, -freq_variation, false)
            end
        end
    end

    local c = unicode_char(true) ---@type integer
    if gamepad_button() then
        c = 32
    end

    if selected_item ~= -1 and c ~= 0 then
        local tmp = menu[selected_item + INDEX_BASE].proc(menu[selected_item + INDEX_BASE], DEMO_MENU_MSG_CHAR, c)
        if tmp == DEMO_MENU_LOCK then
            locked = true
            return DEMO_MENU_CONTINUE
        else
            locked = false
            return tmp
        end
    end

    return DEMO_MENU_CONTINUE
end
exports.update_demo_menu = update_demo_menu


---@param menu DEMO_MENU[]
local function draw_demo_menu(menu)
    local logo_text = "Demo Game"

    draw_background()
    draw_credits()

    ---@type integer
    local x = math.floor(_global.screen_width / 2)
    ---@type integer
    local y = math.floor(1 * _global.screen_height / 6) -
        math.floor(allegro5.al_get_font_line_height(_global.demo_font_logo) / 2)
    demo_textprintf_centre(_global.demo_font_logo, x + 6, y + 5,
        allegro5.al_map_rgba_f(0.125, 0.125, 0.125, 0.25), logo_text)
    demo_textprintf_centre(_global.demo_font_logo, x, y, allegro5.al_map_rgb_f(1, 1, 1), logo_text)

    --[[ calculate height of the whole menu and the starting y coordinate --]]
    local h = 0 ---@type integer
    for _, item in ipairs(menu) do
        if not item.proc then
            break
        end
        h = h + (item.proc(item, DEMO_MENU_MSG_HEIGHT, 0))
    end
    h = h + 2 * 8
    y = math.floor(3 * _global.screen_height / 5) - math.floor(h / 2)

    --[[ calculate the width of the whole menu --]]
    local w = 0 ---@type integer
    for _, item in ipairs(menu) do
        if not item.proc then
            break
        end
        local tmp = item.proc(item, DEMO_MENU_MSG_WIDTH, 0)
        item.w = tmp
        item.x = math.floor((_global.screen_width - tmp) / 2)
        if tmp > w then
            w = tmp
        end
    end
    w = w + (2 * 8)
    if w < _global.screen_width / 3 then
        w = math.floor(_global.screen_width / 3)
    end
    if w > _global.screen_width then
        w = _global.screen_width
    end
    x = math.floor((_global.screen_width - w) / 2)

    --[[ draw menu background --]]
    allegro5.al_draw_filled_rectangle(x, y, x + w, y + h,
        allegro5.al_map_rgba_f(0.37 * 0.6, 0.42 * 0.6, 0.45 * 0.6, 0.6))
    allegro5.al_draw_rectangle(x, y, x + w, y + h, allegro5.al_map_rgb(0, 0, 0), 1)

    --[[ draw menu items --]]
    y = y + 8
    for _, item in ipairs(menu) do
        if not item.proc then
            break
        end
        item.proc(item, DEMO_MENU_MSG_DRAW, y)
        item.y = y
        local tmp = item.proc(item, DEMO_MENU_MSG_HEIGHT, 0) ---@type integer
        item.h = tmp
        y = y + tmp ---@type integer
    end
end
exports.draw_demo_menu = draw_demo_menu


---@param item DEMO_MENU
---@param msg integer
---@param extra integer
---@return integer
local function demo_text_proc(item, msg, extra)
    if msg == DEMO_MENU_MSG_DRAW then
        shadow_textprintf(_global.demo_font, math.floor(_global.screen_width / 2),
            extra, allegro5.al_map_rgb(210, 230, 255), 2, item.name)
    elseif msg == DEMO_MENU_MSG_WIDTH then
        return allegro5.al_get_text_width(_global.demo_font, item.name)
    elseif msg == DEMO_MENU_MSG_HEIGHT then
        return allegro5.al_get_font_line_height(_global.demo_font) + 8
    end

    return DEMO_MENU_CONTINUE
end
exports.demo_text_proc = demo_text_proc


---@param item DEMO_MENU
---@param msg integer
---@param extra integer
---@return integer
local function demo_edit_proc(item, msg, extra)
    if msg == DEMO_MENU_MSG_DRAW then
        local col ---@type ALLEGRO_COLOR
        if bit.band(item.flags, DEMO_MENU_SELECTED) ~= 0 then
            col = allegro5.al_map_rgb(255, 255, 0)
        else
            col = allegro5.al_map_rgb(255, 255, 255)
        end

        local w = demo_edit_proc(item, DEMO_MENU_MSG_WIDTH, 0) ---@type integer
        local h = allegro5.al_get_font_line_height(_global.demo_font) ---@type integer

        allegro5.al_draw_filled_rectangle(math.floor((_global.screen_width - w) / 2) - 2, extra - 2,
            math.floor((_global.screen_width + w) / 2) + 2, extra + h + 2, allegro5.al_map_rgb(0, 0, 0))
        allegro5.al_draw_rectangle(math.floor((_global.screen_width - w) / 2) - 2, extra - 2,
            math.floor((_global.screen_width + w) / 2) + 2, extra + h + 2, col, 1)
        shadow_textprintf(_global.demo_font, math.floor(_global.screen_width / 2),
            extra, col, 2, item.name)
        if bit.band(item.flags, DEMO_MENU_SELECTED) ~= 0 then
            local x = math.floor((_global.screen_width + allegro5.al_get_text_width(_global.demo_font, item.name)) / 2) + 2 ---@type integer
            allegro5.al_draw_line(x + 0.5, extra + 2, x + 0.5, extra + h - 2, col, 1)
            allegro5.al_draw_line(x + 1.5, extra + 2, x + 1.5, extra + h - 2, col, 1)
        end
    elseif msg == DEMO_MENU_MSG_CHAR then
        local l = #item.name ---@type integer
        if extra == 8 then
            if l > 0 then
                item.name = item.name:sub(1, l - 1)

                if item.on_activate then
                    item.on_activate(item)
                end

                play_sound_id(DEMO_SAMPLE_BUTTON, 255, 128, -freq_variation, false)
            end
        else
            local c = bit.band(extra, 0xff) ---@type integer
            if l < item.extra and c >= 0x20 and c < 0x7f then
                item.name = item.name .. string.char(c)

                if item.on_activate then
                    item.on_activate(item)
                end

                play_sound_id(DEMO_SAMPLE_BUTTON, 255, 128, -freq_variation, false)
            end
        end
    elseif msg == DEMO_MENU_MSG_WIDTH then
        return MAX(allegro5.al_get_text_width(_global.demo_font, item.name),
            item.extra * allegro5.al_get_text_width(_global.demo_font, " "))
    elseif msg == DEMO_MENU_MSG_HEIGHT then
        return allegro5.al_get_font_line_height(_global.demo_font) + 8
    end

    return DEMO_MENU_CONTINUE
end
exports.demo_edit_proc = demo_edit_proc


---@param item DEMO_MENU
---@param msg integer
---@param extra integer
---@return integer
local function demo_button_proc(item, msg, extra)
    if msg == DEMO_MENU_MSG_DRAW then
        local col ---@type ALLEGRO_COLOR
        if bit.band(item.flags, DEMO_MENU_SELECTED) ~= 0 then
            col = allegro5.al_map_rgb(255, 255, 0)
        else
            col = allegro5.al_map_rgb(255, 255, 255)
        end

        shadow_textprintf(_global.demo_font, math.floor(_global.screen_width / 2),
            extra, col, 2, item.name)
    elseif msg == DEMO_MENU_MSG_CHAR then
        if extra == 13 or extra == 32 then
            if item.on_activate then
                item.on_activate(item)
            end

            play_sound_id(DEMO_SAMPLE_BUTTON, 255, 128, -freq_variation, false)
            return item.extra
        end
    elseif msg == DEMO_MENU_MSG_WIDTH or msg == DEMO_MENU_MSG_HEIGHT then
        return demo_text_proc(item, msg, extra)
    end

    return DEMO_MENU_CONTINUE
end
exports.demo_button_proc = demo_button_proc


---@param item DEMO_MENU
---@param msg integer
---@param extra integer
---@return integer
local function demo_choice_proc(item, msg, extra)
    local slider_width = math.floor(_global.screen_width / 6) ---@type integer

    --[[ count number of choices --]]
    local choice_count = #item.data ---@type integer

    if msg == DEMO_MENU_MSG_DRAW then
        if choice_count == 0 then
            return DEMO_MENU_CONTINUE
        end
        local col ---@type ALLEGRO_COLOR
        if bit.band(item.flags, DEMO_MENU_SELECTED) ~= 0 then
            col = allegro5.al_map_rgb(255, 255, 0)
        else
            col = allegro5.al_map_rgb(255, 255, 255)
        end

        --[[ starting position --]]
        local x = math.floor((_global.screen_width - slider_width) / 2) ---@type integer

        --[[ print name of the item --]]
        shadow_textprintf(_global.demo_font, x - 8, extra, col, 1,
            item.name)

        --[[ draw slider thingy --]]
        local ch = math.floor(allegro5.al_get_font_line_height(_global.demo_font) / 2) ---@type integer
        ch = MAX(8, ch)
        local dy = math.floor((allegro5.al_get_font_line_height(_global.demo_font) - ch) / 2) ---@type integer

        --[[ shadow --]]
        allegro5.al_draw_rectangle(x + _global.shadow_offset,
            extra + dy + _global.shadow_offset,
            x + slider_width + _global.shadow_offset, extra + dy + ch + _global.shadow_offset,
            allegro5.al_map_rgb(0, 0, 0), 1)
        local cw = math.floor((slider_width - 4) / choice_count) ---@type integer
        cw = MAX(cw, 8)
        local cx = math.floor((slider_width - 4) * item.extra / choice_count) ---@type integer
        if cx + cw > slider_width - 4 then
            cx = slider_width - 4 - cw ---@type integer
        end
        if item.extra == choice_count - 1 then
            cw = slider_width - 4 - cx
        end
        allegro5.al_draw_filled_rectangle(x + 3 + cx, extra + dy + 3,
            x + 3 + cx + cw, extra + dy + ch, allegro5.al_map_rgb(0, 0, 0))

        --[[ slider --]]
        allegro5.al_draw_rectangle(x, extra + dy, x + slider_width, extra + dy + ch,
            col, 1)
        allegro5.al_draw_filled_rectangle(x + 2 + cx, extra + dy + 2, x + 2 + cx + cw,
            extra + dy + ch - 2, col)

        x = x + slider_width

        --[[ print selected choice --]]
        shadow_textprintf(_global.demo_font, x + 8, extra, col,
            0, tostring(item.data[item.extra + INDEX_BASE]))
    elseif msg == DEMO_MENU_MSG_KEY then
        if key_pressed(allegro5.ALLEGRO_KEY_LEFT) then
            if item.extra > 0 then
                item.extra = item.extra - 1
                play_sound_id(DEMO_SAMPLE_BUTTON, 255, 128, -freq_variation, false)

                if item.on_activate then
                    item.on_activate(item)
                end
            end
        end

        if key_pressed(allegro5.ALLEGRO_KEY_RIGHT) then
            if item.extra < choice_count - 1 then
                item.extra = item.extra + 1
                play_sound_id(DEMO_SAMPLE_BUTTON, 255, 128, -freq_variation, false)

                if item.on_activate then
                    item.on_activate(item)
                end
            end
        end
    elseif msg == DEMO_MENU_MSG_CHAR and extra == 13 then
        if mouse_button_pressed(1) then
            local x = math.floor((_global.screen_width - slider_width) / 2) ---@type integer
            item.extra = math.floor((mouse_x() - x) * choice_count / slider_width)
            play_sound_id(DEMO_SAMPLE_BUTTON, 255, 128, -freq_variation, false)
            if item.on_activate then
                item.on_activate(item)
            end
        end
    elseif msg == DEMO_MENU_MSG_WIDTH then
        local cw = allegro5.al_get_text_width(_global.demo_font, item.name) ---@type integer
        for _, data in ipairs(item.data) do ---@diagnostic disable-line: no-unknown
            local tmp = allegro5.al_get_text_width(_global.demo_font, tostring(data))
            if tmp > cw then
                cw = tmp
            end
        end

        return MAX(allegro5.al_get_text_width(_global.demo_font, item.name), cw) * 2 + slider_width + 2 * 8
    elseif msg == DEMO_MENU_MSG_HEIGHT then
        return demo_text_proc(item, msg, extra)
    end

    return DEMO_MENU_CONTINUE
end
exports.demo_choice_proc = demo_choice_proc


---@param item DEMO_MENU
---@param msg integer
---@param extra integer
---@return integer
local function demo_key_proc(item, msg, extra)
    if msg == DEMO_MENU_MSG_DRAW then
        local col ---@type ALLEGRO_COLOR
        if bit.band(item.flags, DEMO_MENU_SELECTED) ~= 0 then
            col = allegro5.al_map_rgb(255, 255, 0)
        else
            col = allegro5.al_map_rgb(255, 255, 255)
        end

        shadow_textprintf(_global.demo_font, math.floor(_global.screen_width / 2) - 16,
            extra, col, 1, item.name)

        if bit.band(item.flags, DEMO_MENU_EXTRA) ~= 0 then
            shadow_textprintf(_global.demo_font,
                math.floor(_global.screen_width / 2) + 16, extra, col, 0, "...")
        else
            shadow_textprintf(_global.demo_font,
                math.floor(_global.screen_width / 2) + 16, extra, col, 0,
                controller[_global.controller_id + INDEX_BASE].
                get_button_description(controller[_global.controller_id + INDEX_BASE],
                    item.extra))
        end
    elseif msg == DEMO_MENU_MSG_CHAR then
        if extra == 13 or extra == 32 then
            item.flags = bit.bor(item.flags, DEMO_MENU_EXTRA)
            play_sound_id(DEMO_SAMPLE_BUTTON, 255, 128, -freq_variation, false)
            return DEMO_MENU_LOCK
        end
    elseif msg == DEMO_MENU_MSG_TICK then
        if bit.band(item.flags, DEMO_MENU_EXTRA) ~= 0 then
            if controller[_global.controller_id + INDEX_BASE].
                calibrate_button(controller[_global.controller_id + INDEX_BASE], item.extra) then
                item.flags = bit.band(item.flags, bit.bnot(DEMO_MENU_EXTRA))
                play_sound_id(DEMO_SAMPLE_BUTTON, 255, 128, -freq_variation, false)
                if item.on_activate then
                    item.on_activate(item)
                end
                return DEMO_MENU_LOCK
            elseif key_pressed(allegro5.ALLEGRO_KEY_ESCAPE) then
                item.flags = bit.band(item.flags, bit.bnot(DEMO_MENU_EXTRA))
                return DEMO_MENU_LOCK
            end
        end
    elseif msg == DEMO_MENU_MSG_WIDTH then
        ---@type integer
        local w1 = allegro5.al_get_text_width(_global.demo_font, item.name)
        ---@type integer
        local w2 = allegro5.al_get_text_width(_global.demo_font,
            (function()
                if bit.band(item.flags, DEMO_MENU_EXTRA) ~= 0 then
                    return "..."
                else
                    return controller[_global.controller_id + INDEX_BASE].get_button_description(controller[_global.controller_id + INDEX_BASE],
                        item.extra)
                end
            end)())

        return 2 * (16 + ((function() if (w2 > w1) then return w2 else return w1 end end)()))
    elseif msg == DEMO_MENU_MSG_HEIGHT then
        return demo_text_proc(item, msg, extra)
    end

    return DEMO_MENU_CONTINUE
end
exports.demo_key_proc = demo_key_proc


---@param item DEMO_MENU
---@param msg integer
---@param extra integer
---@return integer
local function demo_color_proc(item, msg, extra)
    local rgb = {0, 0, 0} ---@type [integer, integer, integer]
    local changed = false
    local slider_width = math.floor(_global.screen_width / 6) ---@type integer

    slider_width = math.floor(slider_width / 3)
    slider_width = slider_width - 4

    if msg == DEMO_MENU_MSG_DRAW then
        local col1, col2 ---@type ALLEGRO_COLOR, ALLEGRO_COLOR
        if bit.band(item.flags, DEMO_MENU_SELECTED) ~= 0 then
            col1 = allegro5.al_map_rgb(255, 255, 0)
            col2 = allegro5.al_map_rgb(255, 255, 255)
        else
            col1 = allegro5.al_map_rgb(255, 255, 255)
            col2 = allegro5.al_map_rgb(255, 255, 255)
        end

        local x = math.floor(_global.screen_width / 2) - math.floor((slider_width + 4) * 3 / 2) ---@type integer
        local h = allegro5.al_get_font_line_height(_global.demo_font) ---@type integer

        shadow_textprintf(_global.demo_font, x - 8, extra, col1,
            1, item.name)

        local c = item.data[0 + INDEX_BASE] ---@type integer
        rgb[0 + INDEX_BASE] = bit.band(c, 255)
        rgb[1 + INDEX_BASE] = bit.band((bit.rshift(c, 8)), 255)
        rgb[2 + INDEX_BASE] = bit.band((bit.rshift(c, 16)), 255)

        for i = 0, 3 - INDEX_BASE do
            local cw = 4 ---@type integer
            local cx = math.floor((slider_width - 4 - cw) * rgb[i + INDEX_BASE] / 255) ---@type integer

            allegro5.al_draw_rectangle(x + 2, extra + 5,
                x + slider_width + 2, extra + h - 1, allegro5.al_map_rgb(0, 0, 0), 1)
            allegro5.al_draw_filled_rectangle(x + 3 + cx, extra + 6,
                x + 3 + cx + cw, extra + h - 4, allegro5.al_map_rgb(0, 0, 0))

            allegro5.al_draw_rectangle(x, extra + 3, x + slider_width,
                extra + h - 3, (function() if item.extra == i then return col1 else return col2 end end)(), 1)
            allegro5.al_draw_filled_rectangle(x + 2 + cx, extra + 5,
                x + 2 + cx + cw, extra + h - 5,
                (function() if item.extra == i then return col1 else return col2 end end)())

            x = x + (slider_width + 4) ---@type integer
        end

        local buf = string.format("%d,%d,%d", rgb[0 + INDEX_BASE], rgb[1 + INDEX_BASE], rgb[2 + INDEX_BASE])
        shadow_textprintf(_global.demo_font, x + 8, extra,
            allegro5.al_map_rgb(rgb[0 + INDEX_BASE], rgb[1 + INDEX_BASE], rgb[2 + INDEX_BASE]), 0, buf)
    elseif msg == DEMO_MENU_MSG_KEY then
        local c = item.data[0 + INDEX_BASE] ---@type integer

        rgb[0 + INDEX_BASE] = bit.band((bit.rshift(c, 0)), 255)
        rgb[1 + INDEX_BASE] = bit.band((bit.rshift(c, 8)), 255)
        rgb[2 + INDEX_BASE] = bit.band((bit.rshift(c, 16)), 255)



        if key_pressed(allegro5.ALLEGRO_KEY_LEFT) then
            if rgb[item.extra + INDEX_BASE] > 0 then
                if key_down(allegro5.ALLEGRO_KEY_LSHIFT) or key_down(allegro5.ALLEGRO_KEY_RSHIFT) then
                    rgb[item.extra + INDEX_BASE] = rgb[item.extra + INDEX_BASE] - 1
                else
                    rgb[item.extra + INDEX_BASE] = rgb[item.extra + INDEX_BASE] - 16
                    rgb[item.extra + INDEX_BASE] = MAX(0, rgb[item.extra + INDEX_BASE])
                end

                changed = true
            end
        end

        if key_pressed(allegro5.ALLEGRO_KEY_RIGHT) then
            if rgb[item.extra + INDEX_BASE] < 255 then
                if key_down(allegro5.ALLEGRO_KEY_LSHIFT) or key_down(allegro5.ALLEGRO_KEY_RSHIFT) then
                    rgb[item.extra + INDEX_BASE] = rgb[item.extra + INDEX_BASE] + 1
                else
                    rgb[item.extra + INDEX_BASE] = rgb[item.extra + INDEX_BASE] + (16)
                    rgb[item.extra + INDEX_BASE] = MIN(255, rgb[item.extra + INDEX_BASE])
                end

                changed = true
            end
        end

        if key_pressed(allegro5.ALLEGRO_KEY_TAB) then
            if key_down(allegro5.ALLEGRO_KEY_LSHIFT) or key_down(allegro5.ALLEGRO_KEY_RSHIFT) then
                item.extra = item.extra - 1
                if item.extra < 0 then
                    item.extra = item.extra + 3
                end
            else
                item.extra = item.extra + 1
                item.extra = item.extra % 3
            end
            play_sound_id(DEMO_SAMPLE_BUTTON, 255, 128, -freq_variation, false)
            if item.on_activate then
                item.on_activate(item)
            end
        end

        if changed then
            ---@diagnostic disable-next-line: no-unknown
            item.data[0 + INDEX_BASE] = rgb[0 + INDEX_BASE] + bit.lshift(rgb[1 + INDEX_BASE], 8) + bit.lshift(rgb[2 + INDEX_BASE], 16)

            play_sound_id(DEMO_SAMPLE_BUTTON, 255, 128, -freq_variation, false)

            if item.on_activate then
                item.on_activate(item)
            end
        end
    elseif msg == DEMO_MENU_MSG_WIDTH then
        return MAX(allegro5.al_get_text_width(_global.demo_font, item.name) * 2 + 8 * 2 +
            3 * (slider_width + 4),
            8 * 2 + 3 * (slider_width + 4) +
            2 * allegro5.al_get_text_width(_global.demo_font, "255,255,255"))
    elseif msg == DEMO_MENU_MSG_HEIGHT then
        return allegro5.al_get_font_line_height(_global.demo_font)
    end

    return DEMO_MENU_CONTINUE
end
exports.demo_color_proc = demo_color_proc


---@param item DEMO_MENU
---@param msg integer
---@param extra integer
---@return integer
local function demo_separator_proc(item, msg, extra)
    if msg == DEMO_MENU_MSG_WIDTH then
        return extra - extra
    elseif msg == DEMO_MENU_MSG_HEIGHT then
        return item.extra
    end

    return DEMO_MENU_CONTINUE
end
exports.demo_separator_proc = demo_separator_proc

return exports
