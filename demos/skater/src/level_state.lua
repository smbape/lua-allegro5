local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/level_state.c
--]]

local allegro5_lua = require("allegro5_lua")
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local quadtree = require("quadtree")

local new_table = common.new_table

local INDEX_BASE = 1 -- lua is 1-based indexed

local OBJFLAGS_VISIBLE = quadtree.OBJFLAGS_VISIBLE

--[[ level state struct, which stores the current state of the level - perfect for any future implementation
of loading/saving games --]]
---@class LevelState
---@field Length integer
---@field Data? integer[]
---@field DoorOpen boolean
---@overload fun(Length? : integer, Data? : integer[], DoorOpen? : boolean): LevelState
local LevelState = common.class({
    __name = "LevelState",

    ---@param self LevelState
    ---@param Length? integer
    ---@param Data? integer[]
    ---@param DoorOpen? boolean
    __init__ = function(self, Length, Data, DoorOpen)
        if Length == nil then Length = 0 end
        if DoorOpen == nil then DoorOpen = false end
        self.Length = Length
        self.Data = Data
        self.DoorOpen = DoorOpen
    end
})
exports.LevelState = LevelState

local SetDoorOpen


---@param NewLev Level?
---@return LevelState?
local function BorrowState(NewLev)
    if not NewLev then
        return nil
    end

    local St = LevelState()
    St.Length = bit.rshift(NewLev.TotalObjects + 31, 5)
    St.Data = new_table(0, St.Length)

    local ObjCount = 0 ---@type integer
    for _, O in ipairs(NewLev.AllObjects) do
        if bit.band(O.Flags, OBJFLAGS_VISIBLE) ~= 0 then
            St.Data[bit.rshift(ObjCount, 5) + INDEX_BASE] = bit.bor(St.Data[bit.rshift(ObjCount, 5) + INDEX_BASE],
                bit.lshift(1, bit.band(ObjCount, 31)))
        end
        ObjCount = ObjCount + 1 ---@type integer
    end

    St.DoorOpen = (NewLev.Door.Image == NewLev.DoorOpen)

    return St
end
exports.BorrowState = BorrowState

---@param NewLev Level?
---@param State LevelState?
local function ReturnState(NewLev, State)
    if not State or not NewLev then
        return
    end

    local ObjCount = 0 ---@type integer
    for _, O in ipairs(NewLev.AllObjects) do
        if bit.band(State.Data[bit.rshift(ObjCount, 5) + INDEX_BASE], bit.lshift(1, bit.band(ObjCount, 31))) ~= 0 then
            O.Flags = bit.bor(O.Flags, OBJFLAGS_VISIBLE)
        else
            O.Flags = bit.band(O.Flags, bit.bnot(OBJFLAGS_VISIBLE))
        end
        ObjCount = ObjCount + 1 ---@type integer
    end

    if State.DoorOpen then
        SetDoorOpen(NewLev)
    end
end
exports.ReturnState = ReturnState

---@param State LevelState?
local function FreeState(State)
    if not State then
        return
    end

    State.Data = nil
end
exports.FreeState = FreeState

---@param lvl Level
local function SetInitialState(lvl)
    ReturnState(lvl, lvl.InitialState)
end
exports.SetInitialState = SetInitialState

---@param Lvl Level
SetDoorOpen = function(Lvl)
    Lvl.Door.Image = Lvl.DoorOpen
end
exports.SetDoorOpen = SetDoorOpen

return exports
