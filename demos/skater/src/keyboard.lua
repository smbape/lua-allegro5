local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/keyboard.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local _global = require("global")
local vcontroller = require("vcontroller")

local new_table = common.new_table

local get_config_int = _global.get_config_int
local set_config_int = _global.set_config_int

local VCONTROLLER = vcontroller.VCONTROLLER

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/keyboard.c
--]]

local KEYBUF_SIZE = 16

--[[
 - bit 0: key is down
 - bit 1: key was pressed
 - bit 2: key was released
 --]]
local key_array = new_table(0, allegro5.ALLEGRO_KEY_MAX) ---@type integer[]
local unicode_array = new_table(0, KEYBUF_SIZE) ---@type integer[]
local unicode_count = 0 ---@type integer

---@param k integer
---@return boolean
local function key_down(k)
    return bit.band(key_array[k + INDEX_BASE], 1) ~= 0
end
exports.key_down = key_down

---@param k integer
---@return boolean
local function key_pressed(k)
    return bit.band(key_array[k + INDEX_BASE], 2) ~= 0
end
exports.key_pressed = key_pressed

---@param remove boolean
---@return integer
local function unicode_char(remove)
    if unicode_count == 0 then
        return 0
    end
    local u = unicode_array[0 + INDEX_BASE]
    if remove then
        for i = 1, KEYBUF_SIZE - 1 do
            unicode_array[i] = unicode_array[i + 1]
        end
        unicode_array[KEYBUF_SIZE] = 0
    end
    return u
end
exports.unicode_char = unicode_char

---@param event ALLEGRO_EVENT
local function keyboard_event(event)
    if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
        key_array[event.keyboard.keycode + INDEX_BASE] = bit.bor(key_array[event.keyboard.keycode + INDEX_BASE],
            bit.lshift(1, 0))
        key_array[event.keyboard.keycode + INDEX_BASE] = bit.bor(key_array[event.keyboard.keycode + INDEX_BASE],
            bit.lshift(1, 1))
    elseif event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
        if event.keyboard.unichar and unicode_count < KEYBUF_SIZE then
            unicode_array[unicode_count + INDEX_BASE] = event.keyboard.unichar
            unicode_count = unicode_count + 1 ---@type integer
        end
    elseif event.type == allegro5.ALLEGRO_EVENT_KEY_UP then
        key_array[event.keyboard.keycode + INDEX_BASE] = bit.band(key_array[event.keyboard.keycode + INDEX_BASE],
            bit.bnot(bit.lshift(1, 0)))
        key_array[event.keyboard.keycode + INDEX_BASE] = bit.bor(key_array[event.keyboard.keycode + INDEX_BASE],
            bit.lshift(1, 2))
    end
end
exports.keyboard_event = keyboard_event

local function keyboard_tick()
    --[[ clear pressed/released bits --]]
    for i = 0, allegro5.ALLEGRO_KEY_MAX - INDEX_BASE do
        key_array[i + INDEX_BASE] = bit.band(key_array[i + INDEX_BASE], bit.bnot(bit.lshift(1, 1)))
        key_array[i + INDEX_BASE] = bit.band(key_array[i + INDEX_BASE], bit.bnot(bit.lshift(1, 2)))
    end

    unicode_count = 0
end
exports.keyboard_tick = keyboard_tick

---@param self VCONTROLLER
---@param config_path string
local function read_config(self, config_path)
    local def = {
        allegro5.ALLEGRO_KEY_LEFT,
        allegro5.ALLEGRO_KEY_RIGHT,
        allegro5.ALLEGRO_KEY_SPACE
    }

    local c = allegro5.al_load_config_file(config_path)
    if not c then
        c = allegro5.al_create_config()
    end
    if not c then
        return
    end

    for i = 0, 3 - INDEX_BASE do
        local tmp = string.format("button%d", i)
        self.private_data[i + INDEX_BASE] =
            get_config_int(c, "KEYBOARD", tmp, def[i + INDEX_BASE])
    end

    allegro5.al_destroy_config(c)
end



---@param self VCONTROLLER
---@param config_path string
local function write_config(self, config_path)
    local c = allegro5.al_load_config_file(config_path)
    if not c then
        c = allegro5.al_create_config()
    end
    if not c then
        return
    end

    for i = 0, 3 - INDEX_BASE do
        local tmp = string.format("button%d", i)
        set_config_int(c, "KEYBOARD", tmp, self.private_data[i + INDEX_BASE])
    end

    allegro5.al_save_config_file(config_path, c)
    allegro5.al_destroy_config(c)
end


---@param self VCONTROLLER
local function poll(self)
    local private_data = self.private_data
    if not private_data then
        return
    end

    for i = 1, 3 do
        if key_down(private_data[i]) then
            self.button[i] = true
        else
            self.button[i] = false
        end
    end
end



---@param self VCONTROLLER
---@param i integer
---@return boolean
local function calibrate_button(self, i)
    if key_down(allegro5.ALLEGRO_KEY_ESCAPE) then
        return false
    end

    for c = 1, allegro5.ALLEGRO_KEY_MAX - INDEX_BASE do
        if key_pressed(c) then
            self.private_data[i + INDEX_BASE] = c
            return true
        end
    end

    return false
end


---@param self VCONTROLLER
---@param i integer
---@return string?
local function get_button_description(self, i)
    local private_data = self.private_data
    if not private_data then
        return nil
    end
    return allegro5.al_keycode_to_name(private_data[i + INDEX_BASE])
end



---@param config_path string
---@return VCONTROLLER
local function create_keyboard_controller(config_path)
    local ret = VCONTROLLER()

    ret.private_data = {}
    for i = 1, 3 do
        ret.button[i] = false
        ret.private_data[i] = 0
    end
    ret.poll = poll
    ret.calibrate_button = calibrate_button
    ret.get_button_description = get_button_description
    ret.read_config = read_config
    ret.write_config = write_config

    read_config(ret, config_path)

    return ret
end
exports.create_keyboard_controller = create_keyboard_controller

return exports
