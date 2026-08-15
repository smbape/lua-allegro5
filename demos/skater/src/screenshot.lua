local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/screenshot.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local _global = require("global")

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ Module for taking screenshots for Allegro games.
   Written by Miran Amon.
   version: 1.01
   date: 27. June 2003
--]]


--[[ The structure that actually takes screenshots and counts them. The user
   should create an instance of this structure with create_screenshot()
   and destroy it with destroy_screenshot(). The user should not use the
   contents of the structure directly, the functions for manipulating with
   the screenshot structure should be used instead.
--]]
---@class SCREENSHOT
---@field counter integer
---@field name? string
---@field ext? string
---@overload fun(counter?: integer, name?: integer, ext?: integer): SCREENSHOT
local SCREENSHOT = common.class({
    __name = "SCREENSHOT",

    ---@param self SCREENSHOT
    ---@param counter? integer
    ---@param name? string
    ---@param ext? string
    __init__ = function(self, counter, name, ext)
        if counter == nil then counter = 0 end
        self.counter = counter
        self.name = name
        self.ext = ext
    end
})
exports.SCREENSHOT = SCREENSHOT


--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/screenshot.c
--]]

--[[ Module for taking screenshots for Allegro games - implementation.
   Written by Miran Amon.
--]]

---@param ss SCREENSHOT
local function next_screenshot(ss)
    ss.counter = ss.counter + 1
    if ss.counter >= 10000 then
        ss.counter = 0
        return
    end

    local buf = string.format("%s%04d.%s", ss.name, ss.counter, ss.ext)
    if allegro5.al_filename_exists(buf) then
        next_screenshot(ss)
    end
end


--[[ Creates an instance of the screenshot structure and initializes it. The user
   should call this function somewhere at the beginning of the program and
   use the value it returns to take screenshots. This function makes sure
   previously made screenshots will not be overwritten.

   Parameters:
      char *name - the base of the name for the screenshots; actual names
                   will have their number appended to them; typically the name
                   should have no more than 4 characters (for compatibility)
      char *ext - extension of the screenshot bitmaps; typically this should
                  be either bmp, pcx, tga or lbm, anything else will fail to
                  produce screenshots unless you have and addon library that
                  integrates itself with save_bitmap()

   Returns:
      SCREENSHOT *ss - an instance of the SCREENSHOT structure
--]]
---@param name string
---@param ext string
---@return SCREENSHOT
local function create_screenshot(name, ext)
    local ret = SCREENSHOT()

    ret.name = name
    ret.ext = ext
    ret.counter = -1
    next_screenshot(ret)

    return ret
end
exports.create_screenshot = create_screenshot


--[[ Destroys an SCREENSHOT object. The user should call this function
   when he's done taking screenshots, i.e. at the end of the program.

   Parameters:
      SCREENSHOT *ss - a pointer to an SCREENSHOT object

   Returns:
      nothing
--]]
---@param ss SCREENSHOT?
local function destroy_screenshot(ss)
    if not ss then
        return
    end
    ss.name = nil
    ss.ext = nil
end
exports.destroy_screenshot = destroy_screenshot


--[[ Takes a screenshot and saves it to a file.

   Parameters:
      SCREENSHOT *ss - a pointer to an SCREENSHOT object
      ALLEGRO_BITMAP *buffer - the bitmap from which we take a screenshot; this can be
                       the screen bitmap but taking screenshots from video
                       bitmaps like the screen is a bit slower so if you use a
                       memory double buferring system you should pass your
                       buffer to this function instead

   Returns:
      nothing
--]]
---@param ss SCREENSHOT?
local function take_screenshot(ss)
    if not ss then
        return
    end

    local buf = string.format("%s%04d.%s", ss.name, ss.counter, ss.ext)

    local bmp2 = allegro5.al_create_bitmap(_global.screen_width, _global.screen_height)
    allegro5.al_set_target_bitmap(bmp2)
    allegro5.al_draw_bitmap(allegro5.al_get_backbuffer(_global.screen), 0, 0, 0)
    allegro5.al_set_target_backbuffer(_global.screen)
    allegro5.al_save_bitmap(buf, bmp2)
    allegro5.al_destroy_bitmap(bmp2)

    next_screenshot(ss)
end
exports.take_screenshot = take_screenshot

return exports
