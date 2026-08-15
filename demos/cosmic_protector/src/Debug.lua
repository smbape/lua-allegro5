local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/Debug.hpp
--]]

-- void debug_message(const char *, ...)

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/Debug.cpp
--]]

---@param fmt string
---@param ... any
local function debug_message(fmt, ...)
    io.write(string.format(fmt, ...))
end
exports.debug_message = debug_message

return exports
