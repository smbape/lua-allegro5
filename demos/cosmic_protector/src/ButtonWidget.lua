local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/ButtonWidget.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local Resource = require("Resource")
local ResourceManager = require("ResourceManager").ResourceManager
local Widget = require("Widget").Widget

local RES_LARGEFONT = Resource.RES_LARGEFONT
local RES_SMALLFONT = Resource.RES_SMALLFONT

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

---@class ButtonWidget : Widget
---@field protected x integer
---@field protected y integer
---@field protected center boolean
---@field protected text string
---@overload fun(x : integer, y : integer, center : boolean, text : string): ButtonWidget
local ButtonWidget = common.class({
    __name = "ButtonWidget",
}, Widget)
exports.ButtonWidget = ButtonWidget

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/ButtonWidget.cpp
--]]

---@param self ButtonWidget
---@return boolean
function ButtonWidget.activate(self)
    return false
end

---@param self ButtonWidget
---@param selected boolean
function ButtonWidget.render(self, selected)
    local myfont ---@type ALLEGRO_FONT?
    local rm = ResourceManager.getInstance()

    if self.center then
        if selected then
            myfont = rm:getData(RES_LARGEFONT) ---@type ALLEGRO_FONT?
        else
            myfont = rm:getData(RES_SMALLFONT) ---@type ALLEGRO_FONT?
        end
        allegro5.al_draw_textf(myfont, allegro5.al_map_rgb(255, 255, 255), self.x,
            self.y - math.floor(allegro5.al_get_font_line_height(myfont) / 2), allegro5.ALLEGRO_ALIGN_CENTRE, "%s", self.text)
    end
end

---@param self ButtonWidget
---@param x integer
---@param y integer
---@param center boolean
---@param text string
function ButtonWidget.ButtonWidget(self, x, y, center, text)
    self.x = x
    self.y = y
    self.center = center
    self.text = text
end

return exports
