local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/collision.hpp
--]]

local sqrt = math.sqrt

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/collision.cpp
--]]

---@param x1 number
---@param y1 number
---@param r1 number
---@param x2 number
---@param y2 number
---@param r2 number
---@return boolean
local function checkCircleCollision(x1, y1, r1, x2, y2, r2)
    local dx = x1 - x2
    local dy = y1 - y2
    local dist = sqrt(dx * dx + dy * dy)
    return dist < (r1 + r2)
end
exports.checkCircleCollision = checkCircleCollision

return exports
