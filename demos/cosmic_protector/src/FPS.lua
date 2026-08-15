local exports = {}

--[[
Sources:
     https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/fps.h
--]]

local common = require("examples.common")
local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local Resource = require("Resource").Resource

local new_table = common.new_table

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

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
---@class FPS : Resource
---@field samplesTimerDiff? number[]
---@field nSamples integer
---@field curSample integer
---@field timerInit number
---@field frames integer
---@field seconds number
---@overload fun(nSamples?: integer): FPS
local FPS = common.class({
    __name = "FPS",
}, Resource)
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
---@param self FPS
---@param nSamples? integer
function FPS.FPS(self, nSamples)
    if nSamples == nil or nSamples <= 0 then nSamples = 100 end
    self.nSamples = nSamples
    self:reset()
end


---@param self FPS
---@return FPS
function FPS.get(self)
    return self
end


---@param self FPS
function FPS.reset(self)
    self.samplesTimerDiff = new_table(0, self.nSamples)
    self.curSample = 0
    self.timerInit = allegro5.al_get_time()
    self.frames = 0
    self.seconds = 0
end


--[[ Destroys an FPS object. The user should call this function when he's
    done measuring the FPS, i.e. at the end of the program.

    Parameters:
        FPS *fps - a pointer to an FPS object

    Returns:
        nothing
--]]
---@param self FPS
function FPS.destroy(self)
    self.samplesTimerDiff = nil
    self.nSamples = 0
    self.curSample = 0
    self.timerInit = 0
    self.frames = 0
    self.seconds = 0
end


--[[ Counts the number of drawn frames. The user should call this function
    every time they draw their frame.

    Parameters:
        FPS *fps - a pointer to an FPS object

    Returns:
        nothing
--]]
---@param self FPS
function FPS.frame(self)
    local timerDiff = allegro5.al_get_time() - self.timerInit
    self.curSample = (self.curSample + 1) % self.nSamples
    self.frames = math.min(self.frames + 1, self.nSamples)
    self.seconds = self.seconds - self.samplesTimerDiff[self.curSample + INDEX_BASE] + timerDiff
    self.samplesTimerDiff[self.curSample + INDEX_BASE] = timerDiff
    self.timerInit = allegro5.al_get_time()
end


--[[ Retreives the current frame rate in frames per second. This will actually
    be the average frame rate over the last second.

    Parameters:
        FPS *fps - a pointer to an FPS object

    Returns:
        int fps - the average frame rate over the last second
--]]
---@param self FPS
---@return number fps
function FPS.compute(self)
    if self.seconds == 0 then return 0 end
    return self.frames / self.seconds
end

return exports
