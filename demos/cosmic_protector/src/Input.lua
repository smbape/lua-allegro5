local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/Input.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local cosmic_protector = require("cosmic_protector")
local joypad_c = require("joypad_c")
local Game = require("Game")
local Debug = require("Debug")
local Resource = require("Resource")
local ResourceManager = require("ResourceManager").ResourceManager

local get_joypad_state = joypad_c.get_joypad_state
local is_joypad_connected = joypad_c.is_joypad_connected

local debug_message = Debug.debug_message

local RES_DISPLAY = Resource.RES_DISPLAY
local RES_PLAYER = Resource.RES_PLAYER

local atan2 = math.atan2 or math.atan ---@diagnostic disable-line: deprecated
local fabs = math.abs

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

---@class Touch
---@field id integer
---@field x integer
---@field y integer
---@overload fun(id? : integer, x? : integer, y? : integer): Touch
local Touch = common.class({
    __name = "Touch",

    ---@param self Touch
    ---@param id? integer
    ---@param x? integer
    ---@param y? integer
    __init__ = function(self, id, x, y)
        if id == nil then id = 0 end
        if x == nil then x = 0 end
        if y == nil then y = 0 end
        self.id = id
        self.x = x
        self.y = y
    end
})

---@class Input : Resource
---@field kbdstate ALLEGRO_KEYBOARD_STATE
---@field joystate ALLEGRO_JOYSTICK_STATE
---@field joystick ALLEGRO_JOYSTICK?
---@field input_queue ALLEGRO_EVENT_QUEUE?
---@field joypad_u boolean
---@field joypad_d boolean
---@field joypad_l boolean
---@field joypad_r boolean
---@field joypad_b boolean
---@field joypad_esc boolean
---@field touches Touch[]
---@field controls_at_top boolean
---@field size integer
---@field joyaxis0 number
---@field joyaxis1 number
---@field joyaxis2 number
---@overload fun(): Input
local Input = common.class({
    __name = "Input",
}, Resource.Resource)
exports.Input = Input

function Input.Input(self)
    self.joypad_u = false
    self.joypad_d = false
    self.joypad_l = false
    self.joypad_r = false
    self.joypad_b = false
    self.joypad_esc = false

    self.kbdstate = allegro5.ALLEGRO_KEYBOARD_STATE()
    self.joystate = allegro5.ALLEGRO_JOYSTICK_STATE()
    if allegro5.ALLEGRO_IPHONE then
        self.touches = {}
        self.controls_at_top = false
        self.size = 0
        self.joyaxis0 = 0.0
        self.joyaxis1 = 0.0
        self.joyaxis2 = 0.0
    end
end

function Input.__destroy(self)
end

if allegro5.ALLEGRO_IPHONE then
    ---@param self Input
    function Input.draw(self)
        if is_joypad_connected() then
            return
        end

        local y = (function() if self.controls_at_top then return 0 else return cosmic_protector.BB_H - self.size end end)() ---@type integer
        local ymid = y + math.floor(self.size / 2) ---@type integer
        local ybot = y + self.size ---@type integer
        local thick = 35 ---@type integer

        local tri_color = allegro5.al_map_rgba_f(0.4, 0.4, 0.4, 0.4)
        local fire_color = allegro5.al_map_rgba_f(0.4, 0.1, 0.1, 0.4)

        allegro5.al_draw_triangle(thick, ymid, self.size - thick, y + thick, self.size - thick, ybot - thick, tri_color,
            thick / 4)
        allegro5.al_draw_triangle(self.size * 2 - thick, ymid, self.size + thick, y + thick, self.size + thick,
            ybot - thick, tri_color, thick / 4)

        allegro5.al_draw_filled_circle(cosmic_protector.BB_W - self.size / 2, ymid, (self.size - thick) / 2, fire_color)
    end

    ---@param self Input
    ---@param x integer
    ---@param y integer
    ---@param w integer
    ---@param h integer
    ---@param check_if_controls_at_top? boolean
    ---@return boolean
    function Input.button_pressed(self, x, y, w, h, check_if_controls_at_top)
        if check_if_controls_at_top == nil then check_if_controls_at_top = true end

        local rm = ResourceManager.getInstance()
        local display = rm:getData(RES_DISPLAY) ---@type ALLEGRO_DISPLAY?

        if allegro5.al_get_display_width(display) < 960 then
            x = math.floor(x / 2)
            y = math.floor(y / 2)
            w = math.floor(w / 2)
            h = math.floor(h / 2)
        end

        if check_if_controls_at_top then
            if self.controls_at_top then
                y = y - (cosmic_protector.BB_H - self.size)
            end
        end


        ---@param xx integer
        ---@param yy integer
        ---@return boolean
        local function COLL(xx, yy)
            return xx >= x and xx <= x + w and yy >= y and yy <= y + h
        end

        for i = 1, #self.touches do
            if COLL(self.touches[i].x, self.touches[i].y) then
                return true
            end
        end

        return false
    end
end


---@param self Input
function Input.poll(self)
    if is_joypad_connected() then
        self.joypad_u, self.joypad_d, self.joypad_l, self.joypad_r, self.joypad_b, self.joypad_esc = get_joypad_state()
        return
    end

    if allegro5.ALLEGRO_IPHONE then
        while not allegro5.al_event_queue_is_empty(self.input_queue) do
            local e = allegro5.ALLEGRO_EVENT()
            allegro5.al_get_next_event(self.input_queue, e)
            if e.type == allegro5.ALLEGRO_EVENT_TOUCH_BEGIN then
                local t = Touch()
                t.id = e.touch.id
                t.x = math.floor(e.touch.x)
                t.y = math.floor(e.touch.y)
                local xx = t.x
                local yy = t.y
                local rm = ResourceManager.getInstance()
                local display = rm:getData(RES_DISPLAY) ---@type ALLEGRO_DISPLAY?
                if allegro5.al_get_display_width(display) < 960 then
                    xx = xx * (2) ---@type integer
                    yy = yy * (2) ---@type integer
                end
                if xx > math.floor(cosmic_protector.BB_W / 5 * 2) and xx < math.floor(cosmic_protector.BB_W / 5 * 3) then
                    if yy < cosmic_protector.BB_H / 3 then
                        self.controls_at_top = true
                    elseif yy > cosmic_protector.BB_H * 2 / 3 then
                        self.controls_at_top = false
                    end
                end
                self.touches[#self.touches + 1] = t
            elseif e.type == allegro5.ALLEGRO_EVENT_TOUCH_END then
                for i = 1, #self.touches do
                    if self.touches[i].id == e.touch.id then
                        for j = i + 1, #self.touches do
                            self.touches[j - 1] = self.touches[j]
                        end
                        self.touches[#self.touches] = nil
                        break
                    end
                end
            elseif e.type == allegro5.ALLEGRO_EVENT_TOUCH_MOVE then
                for i = 1, #self.touches do
                    if self.touches[i].id == e.touch.id then
                        self.touches[i].x = math.floor(e.touch.x)
                        self.touches[i].y = math.floor(e.touch.y)
                        break
                    end
                end
            elseif e.type == allegro5.ALLEGRO_EVENT_JOYSTICK_AXIS then
                if e.joystick.axis == 0 then
                    self.joyaxis0 = e.joystick.pos
                elseif e.joystick.axis == 1 then
                    self.joyaxis1 = e.joystick.pos
                else
                    self.joyaxis2 = e.joystick.pos
                end
            end
        end
    else
        while not allegro5.al_event_queue_is_empty(self.input_queue) do
            local e = allegro5.ALLEGRO_EVENT()
            allegro5.al_get_next_event(self.input_queue, e)
            if e.type == allegro5.ALLEGRO_EVENT_JOYSTICK_CONFIGURATION then
                allegro5.al_reconfigure_joysticks()
                if allegro5.al_get_num_joysticks() <= 0 then
                    self.joystick = nil
                else
                    self.joystick = allegro5.al_get_joystick(0)
                end
            end
        end
        if Game.kb_installed then
            allegro5.al_get_keyboard_state(self.kbdstate)
        end
        if self.joystick then
            allegro5.al_get_joystick_state(self.joystick, self.joystate)
        end
    end
end

---@param self Input
---@return number
function Input.lr(self)
    if is_joypad_connected() then
        if self.joypad_l then
            return -1
        end
        if self.joypad_r then
            return 1
        end
        return 0
    end

    if allegro5.ALLEGRO_IPHONE then
        if self:button_pressed(0, cosmic_protector.BB_H - self.size, self.size, self.size) then
            return -1
        end
        return (function() if self:button_pressed(self.size, cosmic_protector.BB_H - self.size, self.size, self.size) then return 1 else return 0 end end)()
    else
        if allegro5.al_key_down(self.kbdstate, allegro5.ALLEGRO_KEY_LEFT) then
            return -1.0
        elseif allegro5.al_key_down(self.kbdstate, allegro5.ALLEGRO_KEY_RIGHT) then
            return 1.0
        elseif self.joystick then
            local pos = self.joystate.stick[0].axis[0] ---@type number
            return (function() if fabs(pos) > 0.1 then return pos else return 0 end end)()
        else
            return 0
        end
    end
end

---@param self Input
---@return number
function Input.ud(self)
    if is_joypad_connected() then
        if self.joypad_u then
            return -1
        end
        if self.joypad_d then
            return 1
        end
        return 0
    end

    if allegro5.ALLEGRO_IPHONE then
        local magnitude = fabs(self.joyaxis0) + fabs(self.joyaxis1)
        if magnitude < 0.3 then
            return 0
        end
        local rm = ResourceManager.getInstance()
        local player = rm:getData(RES_PLAYER) ---@type Player
        local player_a = player:getAngle()

        local display = rm:getData(RES_DISPLAY) ---@type ALLEGRO_DISPLAY?
        if allegro5.al_get_display_orientation(display) == allegro5.ALLEGRO_DISPLAY_ORIENTATION_90_DEGREES then
            player_a = player_a - allegro5.ALLEGRO_PI
        end

        while player_a < 0 do
            player_a = player_a + (allegro5.ALLEGRO_PI * 2)
        end
        while player_a > allegro5.ALLEGRO_PI * 2 do
            player_a = player_a - (allegro5.ALLEGRO_PI * 2)
        end

        local device_a = atan2(-self.joyaxis0, -self.joyaxis1)
        if device_a < 0 then
            device_a = device_a + (allegro5.ALLEGRO_PI * 2)
        end

        local ab = fabs(player_a - device_a)
        if ab < allegro5.ALLEGRO_PI / 4 then
            return -1
        end

        -- brake against velocity vector
        local dx, dy = player:getSpeed()
        local vel_a = atan2(dy, dx)
        vel_a = vel_a - (allegro5.ALLEGRO_PI)
        if allegro5.al_get_display_orientation(display) == allegro5.ALLEGRO_DISPLAY_ORIENTATION_90_DEGREES then
            vel_a = vel_a - allegro5.ALLEGRO_PI
        end

        while vel_a < 0 do
            vel_a = vel_a + (allegro5.ALLEGRO_PI * 2)
        end
        while vel_a > allegro5.ALLEGRO_PI * 2 do
            vel_a = vel_a - (allegro5.ALLEGRO_PI * 2)
        end

        ab = fabs(vel_a - device_a)
        if ab < allegro5.ALLEGRO_PI / 4 then
            return 1
        end

        return 0
    else
        if allegro5.al_key_down(self.kbdstate, allegro5.ALLEGRO_KEY_UP) then
            return -1.0
        elseif allegro5.al_key_down(self.kbdstate, allegro5.ALLEGRO_KEY_DOWN) then
            return 1.0
        elseif self.joystick then
            local pos = self.joystate.stick[0].axis[1] ---@type number
            return (function() if fabs(pos) > 0.1 then return pos else return 0 end end)()
        else
            return 0
        end
    end
end

---@param self Input
---@return boolean
function Input.esc(self)
    if is_joypad_connected() then
        return self.joypad_esc
    end

    if allegro5.al_key_down(self.kbdstate, allegro5.ALLEGRO_KEY_ESCAPE) then
        return true
    elseif self.joystick then
        return self.joystate.button[1] ~= 0
    else
        return false
    end
end

---@param self Input
---@return boolean
function Input.b1(self)
    if is_joypad_connected() then
        return self.joypad_b
    end

    if allegro5.ALLEGRO_IPHONE then
        return self:button_pressed(cosmic_protector.BB_W - self.size, cosmic_protector.BB_H - self.size, self.size,
            self.size)
    else
        if allegro5.al_key_down(self.kbdstate, allegro5.ALLEGRO_KEY_Z) or allegro5.al_key_down(self.kbdstate, allegro5.ALLEGRO_KEY_Y) then
            return true
        elseif self.joystick then
            return self.joystate.button[0] ~= 0
        else
            return false
        end
    end
end

---@param self Input
---@return boolean
function Input.cheat(self)
    if allegro5.al_key_down(self.kbdstate, allegro5.ALLEGRO_KEY_LSHIFT)
        and allegro5.al_key_down(self.kbdstate, allegro5.ALLEGRO_KEY_EQUALS) then
        return true
    else
        return false
    end
end

---@param self Input
function Input.destroy(self)
end

---@param self Input
---@return boolean
function Input.load(self)
    self.input_queue = allegro5.al_create_event_queue()
    if allegro5.ALLEGRO_IPHONE then
        allegro5.al_install_touch_input()
        allegro5.al_register_event_source(self.input_queue, allegro5.al_get_touch_input_event_source())
        self.controls_at_top = false
        self.size = math.floor(cosmic_protector.BB_W / 5)
    else
        if not Game.kb_installed then
            Game.kb_installed = allegro5.al_install_keyboard()
        end
    end
    if not Game.joy_installed then
        Game.joy_installed = allegro5.al_install_joystick()
    end

    if Game.joy_installed and not self.joystick and allegro5.al_get_num_joysticks() then
        self.joystick = allegro5.al_get_joystick(0)
    end
    if Game.kb_installed then
        debug_message("Keyboard driver installed.\n")
    end
    if self.joystick then
        debug_message("Joystick found.\n")
    end

    if self.joystick then
        allegro5.al_register_event_source(self.input_queue, allegro5.al_get_joystick_event_source())
    end

    if allegro5.ALLEGRO_IPHONE then
        return true
    else
        return Game.kb_installed or self.joystick ~= nil
    end
end

---@param self Input
---@return Input
function Input.get(self)
    return self
end

return exports
