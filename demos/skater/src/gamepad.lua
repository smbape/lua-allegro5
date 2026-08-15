local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/gamepad.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local _global = require("global")
local vcontroller = require("vcontroller")

local get_config_int = _global.get_config_int
local set_config_int = _global.set_config_int

local VCONTROLLER = vcontroller.VCONTROLLER

local INDEX_BASE = 1 -- lua is 1-based indexed

local memset = allegro5_lua.C.memset

local sizeof = function(data)
    return data.__sizeof
end

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi") ---@diagnostic disable-line: no-unknown
    memset = ffi.C.memset ---@type function
    sizeof = ffi.sizeof ---@type function
end

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/gamepad.c
--]]

local button_down = false
local axis = { 0, 0, 0 } ---@type [number, number, number]
local state = allegro5.ALLEGRO_JOYSTICK_STATE()

---@param self VCONTROLLER
---@param config_path string
local function read_config(self, config_path)
    if not self.private_data then
        return
    end

    -- todo set default buttons
    local c = allegro5.al_load_config_file(config_path)
    if not c then
        c = allegro5.al_create_config()
    end

    if not c then
        return
    end

    for i = 0, 3 - INDEX_BASE do
        local tmp = string.format("button%d", i)
        self.private_data[i + INDEX_BASE] = get_config_int(c, "GAMEPAD", tmp, 0)

        if bit.band(bit.rshift(self.private_data[i + INDEX_BASE], 8), 255) >= allegro5.al_get_num_joysticks() then
            self.private_data[i + INDEX_BASE] = 0
        end
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
        set_config_int(c, "GAMEPAD", tmp, self.private_data[i + INDEX_BASE])
    end

    allegro5.al_save_config_file(config_path, c)
    allegro5.al_destroy_config(c)
end

local threshold = 0.1 ---@type number

---@param self VCONTROLLER
local function poll(self)
    --printf("%f %f %f\n", axi + INDEX_BASEs[0], axi + INDEX_BASEs[1], axi + INDEX_BASEs[2]);
    local a = axis[0 + INDEX_BASE]
    if _global.screen_orientation == allegro5.ALLEGRO_DISPLAY_ORIENTATION_90_DEGREES then
        a = axis[1 + INDEX_BASE]
    end
    if _global.screen_orientation == allegro5.ALLEGRO_DISPLAY_ORIENTATION_180_DEGREES then
        a = -axis[0 + INDEX_BASE]
    end
    if _global.screen_orientation == allegro5.ALLEGRO_DISPLAY_ORIENTATION_270_DEGREES then
        a = -axis[1 + INDEX_BASE]
    end
    self.button[0 + INDEX_BASE] = a < -threshold
    self.button[1 + INDEX_BASE] = a > threshold
    self.button[2 + INDEX_BASE] = button_down
end


---@param self VCONTROLLER
---@param i integer
---@return boolean
local function calibrate_button(self, i)
    self.private_data[i + INDEX_BASE] = 0

    local num_joysticks = allegro5.al_get_num_joysticks()
    for joyc = 0, num_joysticks - INDEX_BASE do
        memset(state, 0, sizeof(allegro5.ALLEGRO_JOYSTICK_STATE))

        local joy = allegro5.al_get_joystick(joyc)
        allegro5.al_get_joystick_state(joy, state)
        local num_sticks = allegro5.al_get_joystick_num_sticks(joy)
        local num_buttons = allegro5.al_get_joystick_num_buttons(joy)

        --[[ check axes --]]
        for stickc = 0, num_sticks - INDEX_BASE do
            local num_axis = allegro5.al_get_joystick_num_axes(joy, stickc)

            for axisc = 0, num_axis - INDEX_BASE do
                local value = state.stick[stickc].axis[axisc] ---@type number
                if value ~= 0 then
                    self.private_data[i + INDEX_BASE] =
                        bit.bor(4, bit.bor(bit.lshift(joyc, 8), bit.bor(bit.lshift(stickc, 16), bit.lshift(axisc, 24))))
                    if value < 0 then
                        self.private_data[i + INDEX_BASE] = bit.bor(2, self.private_data[i + INDEX_BASE])
                    end
                    return true
                end
            end
        end

        --[[ check buttons --]]
        for buttonc = 0, num_buttons - INDEX_BASE do
            if state.button[buttonc] > 16384 then
                self.private_data[i + INDEX_BASE] =
                    bit.bor(4, bit.bor(1, bit.bor(bit.lshift(joyc, 8), bit.lshift(buttonc, 16))))
                return true
            end
        end
    end
    return false
end

local RetMessage ---@type string?

---@param self VCONTROLLER
---@param i integer
---@return string
local function get_button_description(self, i)
    local private_data = self.private_data

    if not private_data or private_data[i + INDEX_BASE] == 0 then
        return "Unassigned"
    end

    if bit.band(private_data[i + INDEX_BASE], 1) ~= 0 then
        local joyc = bit.band(bit.rshift(private_data[i + INDEX_BASE], 8), 255)
        local buttonc = bit.rshift(private_data[i + INDEX_BASE], 16)
        local joy = allegro5.al_get_joystick(joyc)
        -- local name = allegro5.al_get_joystick_name(joy)
        local button_name = allegro5.al_get_joystick_button_name(joy, buttonc)
        RetMessage = string.format("Pad %d Button %s", joyc, button_name)
        return RetMessage
    else
        local joyc = bit.band(bit.rshift(private_data[i + INDEX_BASE], 8), 255)
        local stickc = bit.band((bit.rshift(private_data[i + INDEX_BASE], 16)), 255)
        local axisc = bit.rshift(private_data[i + INDEX_BASE], 24)
        local joy = allegro5.al_get_joystick(joyc)
        -- local name = allegro5.al_get_joystick_name(joy)
        -- local stick_name = allegro5.al_get_joystick_stick_name(joy, stickc)
        local axis_name = allegro5.al_get_joystick_axis_name(joy, stickc, axisc)
        RetMessage = string.format("Pad %d Stick %d Axis %s (%s)",
            joyc, stickc, axis_name,
            (function() if bit.band(private_data[i + INDEX_BASE], 2) ~= 0 then return "-" else return "+" end end)())
        return RetMessage
    end
end


---@param config_path string
---@return VCONTROLLER
local function create_gamepad_controller(config_path)
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
exports.create_gamepad_controller = create_gamepad_controller

local function gamepad_event(event)
    if event.type == allegro5.ALLEGRO_EVENT_TOUCH_BEGIN then
        button_down = true
    elseif event.type == allegro5.ALLEGRO_EVENT_TOUCH_END then
        button_down = false
    elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_AXIS then
        if event.joystick.axis < 3 then
            axis[event.joystick.axis + INDEX_BASE] = event.joystick.pos
        end
    elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_CONFIGURATION then
        allegro5.al_reconfigure_joysticks()
    end
end
exports.gamepad_event = gamepad_event


local function gamepad_button()
    return button_down
end
exports.gamepad_button = gamepad_button

return exports
