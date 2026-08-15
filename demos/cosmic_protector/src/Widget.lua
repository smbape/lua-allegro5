local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/Widget.hpp
--]]

local common = require("examples.common")

---@class Widget
local Widget = common.class({
    __name = "Widget",
})
exports.Widget = Widget

---@param self Widget
---@return boolean
function Widget.activate(self)
    error("Implentation needed")
end

---@param self Widget
---@param selected boolean
function Widget.render(self, selected)
    error("Implentation needed")
end

---@param self Widget
function Widget.__destroy(self)
end

return exports
