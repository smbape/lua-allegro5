local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/defines.h
--]]

local demodata = require("demodata")

for k, v in pairs(demodata) do ---@diagnostic disable-line: no-unknown
   exports[k] = v ---@diagnostic disable-line: no-unknown
end

--[[ Error codes. --]]
exports.DEMO_OK = 0
exports.DEMO_ERROR_ALLEGRO = 1
exports.DEMO_ERROR_GFX = 2
exports.DEMO_ERROR_MEMORY = 3
exports.DEMO_ERROR_VIDEOMEMORY = 4
exports.DEMO_ERROR_TRIPLEBUFFER = 5
exports.DEMO_ERROR_DATA = 6
exports.DEMO_ERROR_GAMEDATA = 7

--[[ Screen update driver IDs --]]
exports.DEMO_UPDATE_DIRECT = 0
exports.DEMO_DOUBLE_BUFFER = 1
exports.DEMO_PAGE_FLIPPING = 2
exports.DEMO_TRIPLE_BUFFER = 3
exports.DEMO_OGL_FLIPPING = 4

--[[ Input controller IDs --]]
exports.DEMO_CONTROLLER_KEYBOARD = 0
exports.DEMO_CONTROLLER_GAMEPAD = 1

--[[ Virtual controller button IDs --]]
exports.DEMO_BUTTON_LEFT = 0
exports.DEMO_BUTTON_RIGHT = 1
exports.DEMO_BUTTON_JUMP = 2

--[[ Game state/screen IDs. Each game state must have a unique ID.
   DEMO_STATE_EXIT is a special state that doesn't relate to any
   actual gamestate but represents the final state of the game
   framework state machine. --]]
exports.DEMO_STATE_MAIN_MENU = 0
exports.DEMO_STATE_NEW_GAME = 1
exports.DEMO_STATE_OPTIONS = 2
exports.DEMO_STATE_GFX = 3
exports.DEMO_STATE_SOUND = 4
exports.DEMO_STATE_CONTROLS = 5
exports.DEMO_STATE_MISC = 6
exports.DEMO_STATE_ABOUT = 7
exports.DEMO_STATE_HELP = 8
exports.DEMO_STATE_INTRO = 9
exports.DEMO_STATE_CONTINUE_GAME = 10
exports.DEMO_STATE_SUCCESS = 11
exports.DEMO_STATE_EXIT = -1

--[[ Size of the buffers containing absolute paths to various game files. --]]
exports.DEMO_PATH_LENGTH = 1024

--[[ Size of the static array that holds the game states. --]]
exports.DEMO_MAX_GAMESTATES = 64

--[[ Skater can use both AllegroGL and plain Allegro fonts. AllegroGL fonts
   require somewhat more code but are much faster that Allegro fonts. --]]
--[[ By defualt, use AllegroGL fonts if building in AllegroGL mode. --]]
if os.getenv("DEMO_USE_ALLEGRO_GL") == 1 then
   exports.DEMO_USE_ALLEGRO_GL = true
   exports.DEMO_USE_ALLEGRO_GL_FONT = true
end

return exports
