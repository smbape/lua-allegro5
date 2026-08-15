local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/sound.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local ResourceManager = require("ResourceManager").ResourceManager

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/sound.cpp
--]]

---@param resourceID integer
local function my_play_sample(resourceID)
    local rm = ResourceManager.getInstance()
    local s = rm:getData(resourceID) ---@type ALLEGRO_SAMPLE?
    if s then
        allegro5.al_play_sample(s, 1.0, 0.0, 1.0, allegro5.ALLEGRO_PLAYMODE_ONCE, nil)
    end
end
exports.my_play_sample = my_play_sample

return exports
