local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/gamestate.h
--]]

local common = require("examples.common")

--[[
   Structure that defines one game state/screen/page. Each screen is
   basically just a bunch of functions that initialize the state, run
   a frame of logic and draw it to the screen. Each actual state must
   fill in the struct by setting the function pointers to point to
   the functions that implement that particular state. Note that not
   all functions are mandatory, but most are.
--]]
---@class GAMESTATE
---@field id? fun() : integer
---@field init? fun()
---@field deinit? fun()
---@field update? fun() : integer
---@field draw? fun()
---@overload fun(from?:  GAMESTATE, to?:  GAMESTATE, duration?:  number, progress?:  number, from_bmp?:  ALLEGRO_BITMAP, to_bmp?:  ALLEGRO_BITMAP): GAMESTATE
local GAMESTATE = common.class({
    __name = "GAMESTATE",

    ---@param self GAMESTATE
    ---@param id? fun() : integer
    ---@param init? fun()
    ---@param deinit? fun()
    ---@param update? fun() : integer
    ---@param draw? fun()
    __init__ = function(self, id, init, deinit, update, draw)
        --[[ Supposed to return the ID of the state. Each stat must have a
      unique ID. Not: all actual IDs are defined in defines.h. --]]
        self.id = id

        --[[ Initializes the gamestate. This may be setting some static
      variables to their default values, generating game data,
      randomizing the playing field, etc. --]]
        self.init = init

        --[[ Destroys the gamestate. Note that a particular gamestate may
      set this pointr to NULL if there's nothing to destroy. --]]
        self.deinit = deinit

        --[[ Runs one frame of logic, for example gather input, update game
      physics, enemy AI, do collision detection, etc. Must return ID
      of the next state. Most of the time this should be the ID of
      the state itself, but for example when ESC is pressed this
      should be the ID of the main menu or something along those lines. --]]
        self.update = update

        --[[ Draws the state to the given bitmap. Note that the state should
      assume that the target bitmap is acquired and cleared. --]]
        self.draw = draw
    end
})
exports.GAMESTATE = GAMESTATE

return exports
