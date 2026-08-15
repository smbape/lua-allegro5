local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/joypad_c.h
--]]

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/joypad_dummy.cpp
--]]

--[[ Joypad is some iOS/MacOS X API.
 - This file is just a stub for when it isn't being used.
 - The real implementation is in joypad_handler.m.
 - Most platforms use the regular Allegro joystick API.
 --]]
-- #if !defined(USE_JOYPAD)

local function joypad_start()
end
exports.joypad_start = joypad_start

local function joypad_find()
end
exports.joypad_find = joypad_find

local function joypad_stop_finding()
end
exports.joypad_stop_finding = joypad_stop_finding

---@return boolean u
---@return boolean d
---@return boolean l
---@return boolean r
---@return boolean b
---@return boolean esc
local function get_joypad_state()
    local u, d, l, r, b, esc ---@type boolean, boolean, boolean, boolean, boolean, boolean
    esc = false; b = esc; r = b; l = r; d = l; u = d
    return u, d, l, r, b, esc
end
exports.get_joypad_state = get_joypad_state

---@return boolean
local function is_joypad_connected()
    return false
end
exports.is_joypad_connected = is_joypad_connected

-- #endif /* !USE_JOYPAD */

--[[ vim: set sts=3 sw=3 et: --]]

return exports
