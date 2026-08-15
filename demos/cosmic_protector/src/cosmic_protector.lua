---@class cosmic_protector
---@field switched_out boolean
local exports = {}

--[[
Sources:
   https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/cosmic_protector.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local ResourceManager = require("ResourceManager").ResourceManager
local Resource = require("Resource")

local RES_DISPLAY = Resource.RES_DISPLAY

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
   allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

exports.BB_W = 0
exports.BB_H = 0

local switched_out = false

--[[
Sources:
   https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/cosmic_protector.cpp
--]]

if allegro5.ALLEGRO_IPHONE then
   ---@param halt boolean
   local function switch_game_out(halt)
      -- if not isMultitaskingSupported() then
      --    exit(0)
      -- end
      if halt then
         local rm = ResourceManager.getInstance()
         local display = rm:getData(RES_DISPLAY) ---@type ALLEGRO_DISPLAY
         allegro5.al_acknowledge_drawing_halt(display)
      end
      switched_out = true
   end
   exports.switch_game_out = switch_game_out

   local function switch_game_in()
      switched_out = false
   end
   exports.switch_game_in = switch_game_in

   local getters = {
      switched_out = function() return switched_out end,
   }

   local setters = {
      switched_out = function(value) switched_out = value end,
   }

   setmetatable(exports, {
      __index = function(self, key)
         local getter = getters[key]
         if type(getter) == "function" then
            return getter()
         end
         return nil
      end,
      __newindex = function(self, key, value)
         local setter = setters[key]
         if type(setter) == "function" then
            setter(value)
         else
            rawset(self, key, value)
         end
      end
   })
end

return exports
