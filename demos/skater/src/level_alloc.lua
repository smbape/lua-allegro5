local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/level_alloc.h
--]]

local INDEX_BASE = 1 -- lua is 1-based indexed

local quadtree = require("quadtree")

local OBJFLAGS_VISIBLE = quadtree.OBJFLAGS_VISIBLE

local Edge = quadtree.Edge
local Level = quadtree.Level
local Material = quadtree.Material
local Object = quadtree.Object
local ObjectType = quadtree.ObjectType
local SetupQuadTree = quadtree.SetupQuadTree
local Triangle = quadtree.Triangle
local Vertex = quadtree.Vertex

--[[

   A whole bunch of functions for creating new instances of the various game
   structs. For simplicity these are allocated one at a time by this code,
   although this is likely to lead to very suboptimal memory usage on modern
   operating systems.

   If this were a C++ program, these would be the struct constructors.

   The pattern is quite generic and not really worth too much attention.
   All pointers that may later be the target of memory deallocation are
   set to NULL and in some cases other members of interest are initiated.

--]]

---@return Level
local function NewLevel()
    local l = Level()

    if l then
        -- l.AllTris = nil
        -- l.AllEdges = nil
        -- l.AllMats = nil
        -- l.AllVerts = nil
        -- l.AllObjects = nil
        -- l.AllObjectTypes = nil
        -- l.InitialState = nil
        -- l.DoorShut = nil; l.DoorOpen = l.DoorShut
        -- l.Door.CollectNoise = nil

        SetupQuadTree(l.DisplayTree, -65536, -65536, 65536, 65536)
        SetupQuadTree(l.CollisionTree, -65536, -65536, 65536, 65536)
    end

    return l
end
exports.NewLevel = NewLevel

---@return Material
local function NewMaterial()
    local r = Material()

    r.Next = nil
    r.Fill = nil; r.Edge = r.Fill
    r.Friction = 0
    return r
end
exports.NewMaterial = NewMaterial

---@return ObjectType
local function NewObjectType()
    local r = ObjectType()

    r.Next = nil
    r.Image = nil
    r.CollectNoise = nil
    return r
end
exports.NewObjectType = NewObjectType

---@return Triangle
local function NewTriangle()
    local r = Triangle()

    r.Next = nil
    r.Material = nil
    r.LastFrame = 0
    return r
end
exports.NewTriangle = NewTriangle

---@return Object
local function NewObject()
    local r = Object()

    r.Flags = OBJFLAGS_VISIBLE
    r.ObjType = nil
    return r
end
exports.NewObject = NewObject

---@return Edge
local function NewEdge()
    local r = Edge()

    r.Next = nil
    r.Material = nil
    return r
end
exports.NewEdge = NewEdge

---@return Vertex
local function NewVertex()
    local v = Vertex()

    v.Next = nil
    v.Pos[1 + INDEX_BASE] = 0; v.Pos[0 + INDEX_BASE] = v.Pos[1 + INDEX_BASE]
    v.Edges[1 + INDEX_BASE] = nil; v.Edges[0 + INDEX_BASE] = v.Edges[1 + INDEX_BASE]
    return v
end
exports.NewVertex = NewVertex

return exports
