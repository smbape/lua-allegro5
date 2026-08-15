local exports = {}

--[[
Sources:
     https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/fps.h
--]]

local _global = require("global")
local common = require("examples.common")

local new_table = common.new_table

local INDEX_BASE = 1 -- lua is 1-based indexed

--[[ Module for measuring FPS for Allegro games.
    Written by Miran Amon.
    version: 1.02
    date: 27. June 2003
--]]

--[[ Underlaying structure for measuring FPS. The user should create an instance
    of this structure with create_fps() and destroy it with destroy_fps().
    The user should not use the contents of the structure directly,
    functions for manipulating with the FPS structure should be used instead.
--]]
---@class FPS
---@field samples? integer[]
---@field nSamples integer
---@field curSample integer
---@field frameCounter integer
---@field framesPerSecond integer
---@overload fun(samples?: integer[], nSamples?: integer, curSample?: integer, frameCounter?: integer, framesPerSecond?: integer): FPS
local FPS = common.class({
    __name = "FPS",

    ---@param self FPS
    ---@param samples? integer[]
    ---@param nSamples? integer
    ---@param curSample? integer
    ---@param frameCounter? integer
    ---@param framesPerSecond? integer
    __init__ = function(self, samples, nSamples, curSample, frameCounter, framesPerSecond)
        if nSamples == nil then nSamples = 0 end
        if curSample == nil then curSample = 0 end
        if frameCounter == nil then frameCounter = 0 end
        if framesPerSecond == nil then framesPerSecond = 0 end
        self.samples = samples
        self.nSamples = nSamples
        self.curSample = curSample
        self.frameCounter = frameCounter
        self.framesPerSecond = framesPerSecond
    end
})
exports.FPS = FPS


--[[
Sources:
     https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/fps.c
--]]

--[[ Creates an instance of the FPS structure and initializes it. The user
    should call this function somewhere at the beginning of the program and
    use the value it returns to access the current FPS.

    Parameters:
        int fps - the frequency of the timer used to control the speed of the program

    Returns:
        FPS *fps - an instance of the FPS structure
--]]
---@param fps integer
---@return FPS
local function create_fps(fps)
    local ret = FPS()

    ret.nSamples = fps
    ret.samples = new_table(1, fps)
    ret.curSample = 0
    ret.frameCounter = 0
    ret.framesPerSecond = fps
    return ret
end
exports.create_fps = create_fps


--[[ Destroys an FPS object. The user should call this function when he's
    done measuring the FPS, i.e. at the end of the program.

    Parameters:
        FPS *fps - a pointer to an FPS object

    Returns:
        nothing
--]]
---@param fps FPS?
local function destroy_fps(fps)
    if not fps then return end
    fps.samples = nil
    fps.nSamples = 0
    fps.curSample = 0
    fps.frameCounter = 0
    fps.framesPerSecond = 0
end
exports.destroy_fps = destroy_fps

--[[ Updates the FPS measuring logic. The user should call this function exactly
    fps times per second where fps is the speed of their timer. Usually this is
    implemented in the logic code, i.e. in the while(timer_counter) loop or
    an equivalent.

    Parameters:
        FPS *fps - a pointer to an FPS object

    Returns:
        nothing
--]]
---@param fps FPS?
local function fps_tick(fps)
    if not fps then return end
    fps.curSample = fps.curSample + 1
    fps.curSample = fps.curSample % fps.nSamples
    fps.framesPerSecond = fps.framesPerSecond - fps.samples[fps.curSample + INDEX_BASE]
    fps.framesPerSecond = fps.framesPerSecond + fps.frameCounter
    fps.samples[fps.curSample + INDEX_BASE] = fps.frameCounter
    fps.frameCounter = 0
end
exports.fps_tick = fps_tick


--[[ Counts the number of drawn frames. The user should call this function
    every time they draw their frame.

    Parameters:
        FPS *fps - a pointer to an FPS object

    Returns:
        nothing
--]]
---@param fps FPS?
local function fps_frame(fps)
    if not fps then return end
    fps.frameCounter = fps.frameCounter + 1
end
exports.fps_frame = fps_frame


--[[ Retreives the current frame rate in frames per second. This will actually
    be the average frame rate over the last second.

    Parameters:
        FPS *fps - a pointer to an FPS object

    Returns:
        int fps - the average frame rate over the last second
--]]
---@param fps FPS
---@return integer fps
local function get_fps(fps)
    return fps.framesPerSecond
end
exports.get_fps = get_fps


--[[ Draws the current frame rate on the specified bitmap with the specified
    parameters.

    Parameters:
        FPS *fps     - a pointer to an FPS object
        ALLEGRO_BITMAP *bmp  - destination bitmap
        FONT *font   - the font used for printing the fps
        int x, y     - position of the fps text on the destination bitmap
        int color    - the color of the fps text
        char *format - the format of the text as you would pass to printf(); the
                            format should contain whatever text you wish to print and
                            a format sequence for outputting an integer;

    Returns:
        nothing

    Example:
        draw_fps(fps, screen, font, 100, 50, makecol(123,234,213), "FPS = %d");
--]]
---@param fps FPS?
---@param font ALLEGRO_FONT
---@param x integer
---@param y integer
---@param fg ALLEGRO_COLOR
---@param format string
local function draw_fps(fps, font, x, y, fg, format)
    if not fps then return end
    _global.demo_textprintf_right(font, x, y, fg, format,
        get_fps(fps))
end
exports.draw_fps = draw_fps

return exports
