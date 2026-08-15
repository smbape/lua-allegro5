local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/quadtree.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local _global = require("global")

local new_array = common.new_array
local new_table = common.new_table

local abs = math.abs

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local TRIFLAGS_WIDTH = 0x07f
exports.TRIFLAGS_WIDTH = TRIFLAGS_WIDTH

local TRIFLAGS_EDGE = 0x080
exports.TRIFLAGS_EDGE = TRIFLAGS_EDGE


local OBJFLAGS_VISIBLE = 0x001
exports.OBJFLAGS_VISIBLE = OBJFLAGS_VISIBLE

local OBJFLAGS_DOOR = 0x002
exports.OBJFLAGS_DOOR = OBJFLAGS_DOOR


local FLAGS_COLLIDABLE = 0x100
exports.FLAGS_COLLIDABLE = FLAGS_COLLIDABLE

local FLAGS_FOREGROUND = 0x200
exports.FLAGS_FOREGROUND = FLAGS_FOREGROUND

---@class Material
---@field Edge? ALLEGRO_BITMAP
---@field Fill? ALLEGRO_BITMAP
---@field Friction number
---@field Next? Material
---@overload fun(Edge? : ALLEGRO_BITMAP, Fill? : ALLEGRO_BITMAP, Friction? : number, Next? : Material): Material
local Material = common.class({
    __name = "Material",

    ---@param self Material
    ---@param Edge? ALLEGRO_BITMAP
    ---@param Fill? ALLEGRO_BITMAP
    ---@param Friction? number
    ---@param Next? Material
    __init__ = function(self, Edge, Fill, Friction, Next)
        if Friction == nil then Friction = 0 end
        self.Edge = Edge
        self.Fill = Fill
        self.Friction = Friction
        self.Next = Next
    end
})
exports.Material = Material

---@class Vertex
---@field Pos [number, number]
---@field Normal [number, number]
---@field Edges [Edge?, Edge?]
---@field Next? Vertex
---@overload fun(Pos? : [number, number], Normal? : [number, number], Edges? : [Edge?, Edge?], Next? : Vertex): Vertex
local Vertex = common.class({
    __name = "Vertex",

    ---@param self Vertex
    ---@param Pos? [number, number]
    ---@param Normal? [number, number]
    ---@param Edges? [Edge?, Edge?]
    ---@param Next? Vertex
    __init__ = function(self, Pos, Normal, Edges, Next)
        if Pos == nil then Pos = {0, 0} end
        if Normal == nil then Normal = {0, 0} end
        if Edges == nil then Edges = {} end
        self.Pos = Pos
        self.Normal = Normal
        self.Edges = Edges
        self.Next = Next
    end
})
exports.Vertex = Vertex

---@class SmallVertex
---@field Pos [number, number]
---@overload fun(Pos? : [number, number]): SmallVertex
local SmallVertex = common.class({
    __name = "SmallVertex",

    ---@param self SmallVertex
    ---@param Pos? [number, number]
    __init__ = function(self, Pos)
        if Pos == nil then Pos = {0, 0} end
        self.Pos = Pos
    end
})
exports.SmallVertex = SmallVertex

---@class BoundingBox
---@field TL SmallVertex
---@field BR SmallVertex
---@overload fun(TL? : SmallVertex, BR? : SmallVertex): BoundingBox
local BoundingBox = common.class({
    __name = "BoundingBox",

    ---@param self BoundingBox
    ---@param TL? SmallVertex
    ---@param BR? SmallVertex
    __init__ = function(self, TL, BR)
        if TL == nil then TL = SmallVertex() end
        if BR == nil then BR = SmallVertex() end
        self.TL = TL
        self.BR = BR
    end
})
exports.BoundingBox = BoundingBox

---@class Triangle
---@field Bounder BoundingBox
---@field Material? Material
---@field Next? Triangle
---@field Edges [Vertex?, Vertex?, Vertex?]
---@field EdgeFlags [integer, integer, integer]
---@field LastFrame integer
---@overload fun(Bounder? : BoundingBox, Material? : Material, Next? : Triangle, Edges? : [Vertex?, Vertex?, Vertex?], EdgeFlags? : [integer, integer, integer], LastFrame? : integer): Triangle
local Triangle = common.class({
    __name = "Triangle",

    ---@param self Triangle
    ---@param Bounder? BoundingBox
    ---@param Material_? Material
    ---@param Next? Triangle
    ---@param Edges? [Vertex?, Vertex?, Vertex?]
    ---@param EdgeFlags? [integer, integer, integer]
    ---@param LastFrame? integer
    __init__ = function(self, Bounder, Material_, Next, Edges, EdgeFlags, LastFrame)
        if Bounder == nil then Bounder = BoundingBox() end
        if Edges == nil then Edges = {} end
        if EdgeFlags == nil then EdgeFlags = {0, 0, 0} end
        if LastFrame == nil then LastFrame = 0 end
        self.Bounder = Bounder
        self.Material = Material_
        self.Next = Next
        self.Edges = Edges
        self.EdgeFlags = EdgeFlags
        self.LastFrame = LastFrame
    end
})
exports.Triangle = Triangle

---@class ObjectType
---@field Image? ALLEGRO_BITMAP
---@field CollectNoise? ALLEGRO_SAMPLE
---@field Radius integer
---@field Next? ObjectType
---@overload fun(Image? : ALLEGRO_BITMAP, CollectNoise? : ALLEGRO_SAMPLE, Radius? : integer, Next? : ObjectType): ObjectType
local ObjectType = common.class({
    __name = "ObjectType",

    ---@param self ObjectType
    ---@param Image? ALLEGRO_BITMAP
    ---@param CollectNoise? ALLEGRO_SAMPLE
    ---@param Radius? integer
    ---@param Next? ObjectType
    __init__ = function(self, Image, CollectNoise, Radius, Next)
        if Radius == nil then Radius = 0 end
        self.Image = Image
        self.CollectNoise = CollectNoise
        self.Radius = Radius
        self.Next = Next
    end
})
exports.ObjectType = ObjectType

---@class Object
---@field Bounder BoundingBox
---@field ObjType? ObjectType
---@field Pos [number, number]
---@field Flags integer
---@field Angle number
---@field LastFrame integer
---@overload fun(Image? : ALLEGRO_BITMAP, CollectNoise? : ALLEGRO_SAMPLE, Radius? : integer): Object
local Object = common.class({
    __name = "Object",

    ---@param self Object
    ---@param Bounder? BoundingBox
    ---@param ObjType? ObjectType
    ---@param Pos? [number, number]
    ---@param Flags? integer
    ---@param Angle? number
    ---@param LastFrame? integer
    __init__ = function(self, Bounder, ObjType, Pos, Flags, Angle, LastFrame)
        if Bounder == nil then Bounder = BoundingBox() end
        if Pos == nil then Pos = {0, 0} end
        if Flags == nil then Flags = 0 end
        if Angle == nil then Angle = 0 end
        if LastFrame == nil then LastFrame = 0 end
        self.Bounder = Bounder
        self.ObjType = ObjType
        self.Pos = Pos
        self.Flags = Flags
        self.Angle = Angle
        self.LastFrame = LastFrame
    end
})
exports.Object = Object

---@class Edge
---@field Bounder BoundingBox
---@field Material? Material
---@field Next? Edge
---@field a number
---@field b number
---@field c number
---@field EndPoints Vertex[]
---@overload fun(Bounder? : BoundingBox, Material? : Material, Next? : Edge?, a? : number, b? : number, c? : number, EndPoints? : Vertex[]): Edge
local Edge = common.class({
    __name = "Edge",

    ---@param self Edge
    ---@param Bounder? BoundingBox
    ---@param Material_? Material
    ---@param Next? Edge
    ---@param a? number
    ---@param b? number
    ---@param c? number
    ---@param EndPoints? Vertex[]
    __init__ = function(self, Bounder, Material_, Next, a, b, c, EndPoints)
        if Bounder == nil then Bounder = BoundingBox() end
        if a == nil then a = 0 end
        if b == nil then b = 0 end
        if c == nil then c = 0 end
        if EndPoints == nil then EndPoints = {} end
        self.Bounder = Bounder
        self.Material = Material_
        self.Next = Next
        self.a = a
        self.b = b
        self.c = c
        self.EndPoints = EndPoints
    end
})
exports.Edge = Edge


local TRIANGLE = 0; exports.TRIANGLE = TRIANGLE
local OBJECT = 1; exports.OBJECT = OBJECT
local EDGE = 2; exports.EDGE = EDGE

---@class ContainerContentUnion
---@field E? Edge
---@field T? Triangle
---@field O? Object
---@overload fun(E?: Edge, T?: Triangle, O?: Object): ContainerContentUnion
local ContainerContentUnion = common.class({
    __name = "ContainerContentUnion",

    ---@param self ContainerContentUnion
    ---@param E? Edge
    ---@param T? Triangle
    ---@param O? Object
    __init__ = function(self, E, T, O)
        self.E = E
        self.T = T
        self.O = O
    end,

    __newindex = function(self, index, value)
        rawset(self, index, value)
        rawset(self, "E", value)
        rawset(self, "T", value)
        rawset(self, "O", value)
    end
})

--[[ containers for the two previous elements, used to build lists at tree nodes --]]
---@class Container
---@field Next? Container
---@field Type `TRIANGLE` | `OBJECT` | `EDGE`
---@field Content ContainerContentUnion
---@overload fun(Next?:  Container, Type? : `TRIANGLE` | `OBJECT` | `EDGE`, Content? : ContainerContentUnion): Container
local Container = common.class({
    __name = "Container",

    ---@param self Container
    ---@param Next? Container
    ---@param Type? `TRIANGLE` | `OBJECT` | `EDGE`
    ---@param Content? ContainerContentUnion
    __init__ = function(self, Next, Type, Content)
        if Content == nil then Content = ContainerContentUnion() end
        self.Next = Next
        self.Type = Type
        self.Content = Content
    end
})
exports.Container = Container

--[[ quadtrees of containers --]]
---@class QuadTreeNode
---@field Bounder BoundingBox
---@field NumContents integer
---@field Contents? Container
---@field PostContents? Container
---@field Children? QuadTreeNode[]
---@field Next? QuadTreeNode
---@overload fun(Bounder? : BoundingBox, NumContents? : integer, Contents? : Container, PostContents? : Container, Children? : QuadTreeNode[], Next? : QuadTreeNode): QuadTreeNode
local QuadTreeNode = common.class({
    __name = "QuadTreeNode",

    ---@param self QuadTreeNode
    ---@param Bounder? BoundingBox
    ---@param NumContents? integer
    ---@param Contents? Container
    ---@param PostContents? Container
    ---@param Children? QuadTreeNode[]
    ---@param Next? QuadTreeNode
    __init__ = function(self, Bounder, NumContents, Contents, PostContents, Children, Next)
        if Bounder == nil then Bounder = BoundingBox() end
        if NumContents == nil then NumContents = 0 end
        self.Bounder = Bounder
        self.NumContents = NumContents
        self.Contents = Contents
        self.PostContents = PostContents
        self.Children = Children
        self.Next = Next
    end
})
exports.QuadTreeNode = QuadTreeNode

--[[ level structure, connecting it all --]]
---@class Level
---@field DisplayTree QuadTreeNode
---@field VisibleList? QuadTreeNode
---@field CollisionTree QuadTreeNode
---@field PlayerStartPos [number, number]
---@field TotalObjects integer
---@field ObjectsRequired integer
---@field InitialState? LevelState
---@field AllObjectTypes? ObjectType
---@field Door ObjectType
---@field AllMats? Material
---@field AllVerts? Vertex
---@field AllEdges? Edge
---@field AllTris? Triangle
---@field AllObjects Object[]
---@field DoorOpen? ALLEGRO_BITMAP
---@field DoorShut? ALLEGRO_BITMAP
---@overload fun(DisplayTree? : QuadTreeNode, VisibleList? : QuadTreeNode, CollisionTree? : QuadTreeNode, PlayerStartPos? : [number, number], TotalObjects? : integer, ObjectsRequired? : integer, InitialState? : LevelState, AllObjectTypes? : ObjectType, Door? : ObjectType, AllMats? : Material, AllVerts? : Vertex, AllEdges? : Edge, AllTris? : Triangle, AllObjects? : Object[], DoorOpen? : ALLEGRO_BITMAP, DoorShut? : ALLEGRO_BITMAP): Level
local Level = common.class({
    __name = "Level",

    ---@param self Level
    ---@param DisplayTree? QuadTreeNode
    ---@param VisibleList? QuadTreeNode
    ---@param CollisionTree? QuadTreeNode
    ---@param PlayerStartPos? [number, number]
    ---@param TotalObjects? integer
    ---@param ObjectsRequired? integer
    ---@param InitialState? LevelState
    ---@param AllObjectTypes? ObjectType
    ---@param Door? ObjectType
    ---@param AllMats? Material
    ---@param AllVerts? Vertex
    ---@param AllEdges? Edge
    ---@param AllTris? Triangle
    ---@param AllObjects? Object[]
    ---@param DoorOpen? ALLEGRO_BITMAP
    ---@param DoorShut? ALLEGRO_BITMAP
    __init__ = function(self, DisplayTree, VisibleList, CollisionTree, PlayerStartPos, TotalObjects, ObjectsRequired, InitialState, AllObjectTypes, Door, AllMats, AllVerts, AllEdges, AllTris, AllObjects, DoorOpen, DoorShut)
        if DisplayTree == nil then DisplayTree = QuadTreeNode() end
        if CollisionTree == nil then CollisionTree = QuadTreeNode() end
        if PlayerStartPos == nil then PlayerStartPos = {0, 0} end
        if TotalObjects == nil then TotalObjects = 0 end
        if ObjectsRequired == nil then ObjectsRequired = 0 end
        if Door == nil then Door = ObjectType() end
        if AllObjects == nil then AllObjects = {} end
        self.DisplayTree = DisplayTree
        self.VisibleList = VisibleList
        self.CollisionTree = CollisionTree
        self.PlayerStartPos = PlayerStartPos
        self.TotalObjects = TotalObjects
        self.ObjectsRequired = ObjectsRequired
        self.InitialState = InitialState
        self.AllObjectTypes = AllObjectTypes
        self.Door = Door
        self.AllMats = AllMats
        self.AllVerts = AllVerts
        self.AllEdges = AllEdges
        self.AllTris = AllTris
        self.AllObjects = AllObjects
        self.DoorOpen = DoorOpen
        self.DoorShut = DoorShut
    end
})
exports.Level = Level


--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/quadtree.c
--]]

--[[

   QuadTree.c
   ==========

   A quad tree is a hierarchical tree based structure. For further information
   on quad trees see http://en.wikipedia.org/wiki/Quadtree

   In this code, every node has a pointer named 'Children' which is either NULL
   or points to an array of four children. The children are indexed as follows:

      0 - top left
      1 - top right
      2 - bottom left
      3 - bottom right

   This allows indexing according to a simple bitwise calculation:

      childnum = 0;
      if(x > midpoint) childnum |= 1;
      if(y > midpoint) childnum |= 2;

   The QuadTreeNode structs look like this:

      struct QuadTreeNode
      {
         struct BoundingBox Bounder;

         int NumContents;
         struct Container *Contents;

         struct QuadTreeNode *Children;
      };

   BoundingBox is the axis aligned bounding box for the region of space
   covered, NumContents is a count of the number of items contained in the
   linked list 'Contents'. It is redundant but convenient.

   'Children' is as explained above - NULL if this is a leaf node, otherwise
   a pointer to an array of four QuadTreeNode structs that subdivide the area
   of this node.
--]]

-- #include <allegro5/allegro_primitives.h>
-- #include "level.h"
-- #include "global.h"

--[[

   CentreX and CentreY are macros that evaluate to the centre point of the
   bounding box b

--]]
--- @param b BoundingBox
--- @return number
local function CentreX(b) return (b.TL.Pos[0 + INDEX_BASE] + b.BR.Pos[0 + INDEX_BASE]) * 0.5 end

--- @param b BoundingBox
--- @return number
local function CentreY(b) return (b.TL.Pos[1 + INDEX_BASE] + b.BR.Pos[1 + INDEX_BASE]) * 0.5 end
local ERROR_BOUNDARY = 2

--[[

   GetChild. Returns the child index for a point (qx, qy) in the bounding box
   b. Uses the logic expressed in the comments at the top of this file

--]]
---@param b BoundingBox
---@param qx number
---@param qy number
---@return integer
local function GetChild(b, qx, qy)
    local ret = 0

    if qx > CentreX(b) then
        ret = bit.bor(ret, 1)
    end
    if qy > CentreY(b) then
        ret = bit.bor(ret, 2)
    end
    return ret
end

--[[

   Get[X1/2]/[Y1/2] - if passed a child id and the bounding box of the parent,
   these return the corresponding co-ordinate of the child

--]]
--- @param child integer
--- @param b BoundingBox
--- @return number
local function GetX1(child, b)
    if bit.band(child, 1) ~= 0 then return CentreX(b) else return b.TL.Pos[0 + INDEX_BASE] end
end

--- @param child integer
--- @param b BoundingBox
--- @return number
local function GetX2(child, b)
    if bit.band(child, 1) ~= 0 then return b.BR.Pos[0 + INDEX_BASE] else return CentreX(b) end
end

--- @param child integer
--- @param b BoundingBox
--- @return number
local function GetY1(child, b)
    if bit.band(child, 2) ~= 0 then return CentreY(b) else return b.TL.Pos[1 + INDEX_BASE] end
end

--- @param child integer
--- @param b BoundingBox
--- @return number
local function GetY2(child, b)
    if bit.band(child, 2) ~= 0 then return b.BR.Pos[1 + INDEX_BASE] else return CentreY(b) end
end

--[[

   ToggleChildPtr[X/Y] relate to the way movement is handled by the physics
   code. They use a continuous time method (see Physics.c for more details),
   which means that they need to be able to calculate when a travelling point
   will leave a quad tree node.

   Because there may be rounding errors close to the border, the function for
   obtaining collision edges inspects velocity to determine which child a
   point near the boundary is actually interested in.

   For that purpose, ToggleChildPtr[X/Y] affect which child is looked at
   according to velocity. If the point is heading right it wants the right
   hand side child, if it is heading down it wants the lower child, etc.

--]]
---@param yvec number
---@param oldchild integer
---@return integer
local function ToggleChildPtrY(yvec, oldchild)
    if (yvec > 0 and bit.band(oldchild, 2) ~= 0) or (yvec < 0 and bit.band(oldchild, 2) == 0) then
        oldchild = bit.bxor(oldchild, 2)
    end
    return oldchild
end

---@param xvec number
---@param oldchild integer
---@return integer
local function ToggleChildPtrX(xvec, oldchild)
    if (xvec > 0 and bit.band(oldchild, 1) ~= 0) or (xvec < 0 and bit.band(oldchild, 1) == 0) then
        oldchild = bit.bxor(oldchild, 1)
    end
    return oldchild
end

--[[

   Separated does a test on two bounding boxes to determine whether they
   overlap - returning true if they don't and false if they do.

   It achieves this using the 'separating planes' algorithm, which is a general
   case test that can be expressed very simply for boxes. If the leftmost point
   of one box is to the right of the rightmost point of the other then they
   must not overlap.

   Ditto for the topmost point of one versus the bottommost of the other and
   all variations on those tests.

   These tests will catch all possible ways in which two boxes DO NOT
   overlap. Therefore the only possible conclusion if they all fail is that the
   boxes DO overlap.

   A small error boundary in which non-overlapping objects are returned as
   overlapping anyway is coded here so that we don't get rounding problems
   when doing collisions near the edge of a node

--]]
---@param a BoundingBox
---@param b BoundingBox
---@return boolean
local function Separated(a, b)
    if a.TL.Pos[0 + INDEX_BASE] - ERROR_BOUNDARY > b.BR.Pos[0 + INDEX_BASE] then
        return true
    end
    if a.TL.Pos[1 + INDEX_BASE] - ERROR_BOUNDARY > b.BR.Pos[1 + INDEX_BASE] then
        return true
    end

    if b.TL.Pos[0 + INDEX_BASE] - ERROR_BOUNDARY > a.BR.Pos[0 + INDEX_BASE] then
        return true
    end
    if b.TL.Pos[1 + INDEX_BASE] - ERROR_BOUNDARY > a.BR.Pos[1 + INDEX_BASE] then
        return true
    end

    return false
end

--[[

   GENERIC QUAD TREE FUNCTIONS

--]]

--[[

   SetupQuadTree just initiates a QuadTreeNode struct, filling its bounding
   box appropriately and setting it up to have no contents and no children

--]]
---@param Tree QuadTreeNode
---@param x1 integer
---@param y1 integer
---@param x2 integer
---@param y2 integer
local function SetupQuadTree(Tree, x1, y1, x2, y2)
    Tree.Bounder.TL.Pos[0 + INDEX_BASE] = x1
    Tree.Bounder.TL.Pos[1 + INDEX_BASE] = y1
    Tree.Bounder.BR.Pos[0 + INDEX_BASE] = x2
    Tree.Bounder.BR.Pos[1 + INDEX_BASE] = y2

    Tree.NumContents = 0
    Tree.PostContents = nil; Tree.Contents = Tree.PostContents
    Tree.Children = nil
end
exports.SetupQuadTree = SetupQuadTree

--[[

   FreeQuadTree frees all the memory malloc'd to a QuadTree. It calls itself
   recursively for any children

--]]
---@param Tree QuadTreeNode
local function FreeQuadTree(Tree)
    --[[

   if this node has children then free them

    --]]
    if Tree.Children then
        local c = 4 ---@type integer
        while c ~= 0 do
            c = c - 1
            FreeQuadTree(Tree.Children[c + INDEX_BASE])
        end

        Tree.Children = nil
    end

    --[[ free all edge containers stored here --]]
    while Tree.Contents do
        local CNext = Tree.Contents.Next
        Tree.Contents = CNext
    end
end
exports.FreeQuadTree = FreeQuadTree

--[[

   AddContent adds new content to a QuadTreeNode. The basic steps are these:

      1. does the new content fit into the space covered by this node? If not,
      reject it

      2. is this node subdivided? If so then pass the new content to the
      children to deal with. If not then insert at this node

      3. if inserted at this node, have we now hit the limit for items
      storable at any node? If so, subdivide and pass all contents that were
      stored here to the children

--]]
---@param Tree QuadTreeNode
---@param NewContent Container
---@param divider integer
local function AddContent(Tree, NewContent, divider)
    --[[

      First check: does the refered new content actually overlap with this
      node? If not, do nothing

      NB: this code explicitly checks the bounding box of an 'edge' held in
      NewContent, even though it may hold an edge, triangle or object. This is
      fine because we've set up our structs so that the bounding box
      information is at the same location regardless

    --]]
    if Separated(NewContent.Content.E.Bounder, Tree.Bounder) then
        return
    end

    --[[

      Second check: has this node been subdivided? If so, pass on for
      children to deal with

    --]]
    if Tree.Children then
        local c = 4 ---@type integer
        while c ~= 0 do
            c = c - 1
            AddContent(Tree.Children[c + INDEX_BASE], NewContent, divider)
        end
    else
        --[[

         If we're here, then the edge really does need to be added to the
         current node, so do that

       --]]
        Tree.NumContents = Tree.NumContents + 1
        local CPtr = Tree.Contents ---@type Container?
        Tree.Contents = Container()
        Tree.Contents.Content = NewContent.Content
        Tree.Contents.Type = NewContent.Type
        Tree.Contents.Next = CPtr

        --[[

         Now check if we've hit the maximum content count for this node. If
         so, subdivide

       --]]
        if (Tree.NumContents == divider)
            and ((Tree.Bounder.BR.Pos[0 + INDEX_BASE] - Tree.Bounder.TL.Pos[0 + INDEX_BASE]) > _global.screen_width)
            and ((Tree.Bounder.BR.Pos[1 + INDEX_BASE] - Tree.Bounder.TL.Pos[1 + INDEX_BASE]) > _global.screen_height) then
            --[[ allocate new memory and set up structures --]]
            Tree.Children = new_table(QuadTreeNode, 4)
            local c = 4 ---@type integer
            while c ~= 0 do
                c = c - 1 ---@type integer
                SetupQuadTree(Tree.Children[c + INDEX_BASE],
                    math.floor(GetX1(c, Tree.Bounder)), math.floor(GetY1(c,
                        Tree.
                        Bounder)),
                    math.floor(GetX2(c, Tree.Bounder)), math.floor(GetY2(c, Tree.Bounder)))
            end

            --[[ redistribute contents currently stored here --]]
            CPtr = Tree.Contents
            while CPtr do
                local Next = CPtr.Next ---@type Container?

                c = 4
                while c ~= 0 do
                    c = c - 1
                    AddContent(Tree.Children[c + INDEX_BASE], CPtr, divider)
                end

                CPtr = Next
            end
            Tree.Contents = nil
        end
    end
end

--[[

   STUFF FOR DEALING WITH 'EDGES'

--]]


--[[

   GetNode returns the leaf node that a point is currently in from
   the edge tree, for collisions & physics

--]]
---@param Ptr QuadTreeNode
---@param pos [number, number]
---@param vec [number, number]
---@return QuadTreeNode
local function GetNode(Ptr, pos, vec)
    --[[ continue moving down the tree if we aren't at a leaf --]]
    while Ptr.Children do
        --[[ figure out which child we should prima facie be considering --]]
        local Child = GetChild(Ptr.Bounder, pos[0 + INDEX_BASE], pos[1 + INDEX_BASE])

        --[[ toggle child according to velocity if sufficiently near the boundary --]]
        local MidX = CentreX(Ptr.Bounder)
        local MidY = CentreY(Ptr.Bounder)

        if abs(math.floor(pos[0 + INDEX_BASE]) - MidX) < ERROR_BOUNDARY then
            Child = ToggleChildPtrX(vec[0 + INDEX_BASE], Child)
        end

        if abs(math.floor(pos[1 + INDEX_BASE]) - MidY) < ERROR_BOUNDARY then
            Child = ToggleChildPtrY(vec[1 + INDEX_BASE], Child)
        end

        --[[ and now move ourselves so that we are now looking at that child --]]
        Ptr = Ptr.Children[Child + INDEX_BASE]
    end

    --[[ return the leaf node found --]]
    return Ptr
end

---@param lvl Level
---@param pos [number, number]
---@param vec [number, number]
---@return QuadTreeNode
local function GetCollisionNode(lvl, pos, vec)
    return GetNode(lvl.CollisionTree, pos, vec)
end
exports.GetCollisionNode = GetCollisionNode

--[[

   STUFF FOR DEALING WITH 'TRIANGLES'

--]]

---@param vt ALLEGRO_VERTEX
---@param x number
---@param y number
---@param u number
---@param v number
local function set_v(vt, x, y, u, v)
    vt.x = x
    vt.y = y
    vt.z = 0
    vt.u = u
    vt.v = v
    vt.color = allegro5.al_map_rgb_f(1, 1, 1)
end

--[[

   DrawTriEdge is a drawing function that adds a textured edge to a triangle

--]]
---@param tri Triangle
---@param ScrBounder BoundingBox
local function DrawTriEdge(tri, ScrBounder)
    local PolyEdges, PolyEdges_ptr = new_array("ALLEGRO_VERTEX", 4)

    --[[ quick bounding box check - if the triangle isn't on screen then we can
      forget about it --]]
    if Separated(tri.Bounder, ScrBounder) then
        return
    end
    local c = 3 ---@type integer
    local x, y, w ---@type number, number, number
    while c ~= 0 do
        c = c - 1
        local c2 = (c + 1) % 3
        if bit.band(tri.EdgeFlags[c + INDEX_BASE], TRIFLAGS_EDGE) ~= 0 then
            --[[

            Texture u is determined according to world position so that
            edges that should appear to meet up do.

          --]]
            x = tri.Edges[c + INDEX_BASE].Pos[0 + INDEX_BASE] - ScrBounder.TL.Pos[0 + INDEX_BASE]
            y = tri.Edges[c + INDEX_BASE].Pos[1 + INDEX_BASE] - ScrBounder.TL.Pos[1 + INDEX_BASE]
            w = bit.band(tri.EdgeFlags[c + INDEX_BASE], TRIFLAGS_WIDTH)
            set_v(PolyEdges[0], x, y - w, tri.Edges[c + INDEX_BASE].Pos[0 + INDEX_BASE], 0)
            set_v(PolyEdges[3], x, y + w, tri.Edges[c + INDEX_BASE].Pos[0 + INDEX_BASE], allegro5.al_get_bitmap_height(tri.Material.Edge))
            x = tri.Edges[c2 + INDEX_BASE].Pos[0 + INDEX_BASE] - ScrBounder.TL.Pos[0 + INDEX_BASE] + 1
            y = tri.Edges[c2 + INDEX_BASE].Pos[1 + INDEX_BASE] - ScrBounder.TL.Pos[1 + INDEX_BASE]
            w = bit.band(tri.EdgeFlags[c2 + INDEX_BASE], TRIFLAGS_WIDTH)
            set_v(PolyEdges[1], x, y - w, tri.Edges[c2 + INDEX_BASE].Pos[0 + INDEX_BASE], 0)
            set_v(PolyEdges[2], x, y + w, tri.Edges[c2 + INDEX_BASE].Pos[0 + INDEX_BASE], allegro5.al_get_bitmap_height(tri.Material.Edge))

            allegro5.al_draw_prim(PolyEdges_ptr, nil, tri.Material.Edge, 0, 4, allegro5.ALLEGRO_PRIM_TRIANGLE_FAN)
        end
    end
end

---@param v ALLEGRO_VERTEX
---@param ScrBounder BoundingBox
local function setuv(v, ScrBounder)
    v.u = v.x + ScrBounder.TL.Pos[0 + INDEX_BASE]
    v.v = v.y + ScrBounder.TL.Pos[1 + INDEX_BASE]

    v.z = 0
    v.color = allegro5.al_map_rgb_f(1, 1, 1)
end

--[[

   DrawTriangle is a drawing function that draws a triangle with a textured
   fill

--]]
---@param tri Triangle
---@param ScrBounder BoundingBox
local function DrawTriangle(tri, ScrBounder)
    local v, v_ptr = new_array("ALLEGRO_VERTEX", 3)

    --[[ quick bounding box check - if the triangle isn't on screen then we can
      forget about it --]]
    if Separated(tri.Bounder, ScrBounder) then
        return
    end

    v[0].x = tri.Edges[0 + INDEX_BASE].Pos[0 + INDEX_BASE] - ScrBounder.TL.Pos[0 + INDEX_BASE] ---@type number
    v[0].y = tri.Edges[0 + INDEX_BASE].Pos[1 + INDEX_BASE] - ScrBounder.TL.Pos[1 + INDEX_BASE] ---@type number
    setuv(v[0], ScrBounder)
    v[1].x = tri.Edges[1 + INDEX_BASE].Pos[0 + INDEX_BASE] - ScrBounder.TL.Pos[0 + INDEX_BASE] ---@type number
    v[1].y = tri.Edges[1 + INDEX_BASE].Pos[1 + INDEX_BASE] - ScrBounder.TL.Pos[1 + INDEX_BASE] ---@type number
    setuv(v[1], ScrBounder)
    v[2].x = tri.Edges[2 + INDEX_BASE].Pos[0 + INDEX_BASE] - ScrBounder.TL.Pos[0 + INDEX_BASE] ---@type number
    v[2].y = tri.Edges[2 + INDEX_BASE].Pos[1 + INDEX_BASE] - ScrBounder.TL.Pos[1 + INDEX_BASE] ---@type number
    setuv(v[2], ScrBounder)

    allegro5.al_draw_prim(v_ptr, nil, tri.Material.Fill, 0, 3, allegro5.ALLEGRO_PRIM_TRIANGLE_STRIP)
end

--[[

   DrawObject is a drawing function that draws an object (!)

--]]
---@param obj Object
---@param ScrBounder BoundingBox
local function DrawObject(obj, ScrBounder)
    --[[ quick bounding box check - if the triangle isn't on screen then we can
      forget about it --]]
    if Separated(obj.Bounder, ScrBounder) then
        return
    end

    if bit.band(obj.Flags, OBJFLAGS_VISIBLE) ~= 0 then
        allegro5.al_draw_scaled_rotated_bitmap(obj.ObjType.Image, 0, 0,
            math.floor(0.5 *
                (obj.Bounder.TL.Pos[0 + INDEX_BASE] +
                    obj.Bounder.BR.Pos[0 + INDEX_BASE]) -
                ScrBounder.TL.Pos[0 + INDEX_BASE]) -
            bit.rshift(allegro5.al_get_bitmap_width(obj.ObjType.Image), 1),
            math.floor(0.5 *
                (obj.Bounder.TL.Pos[1 + INDEX_BASE] +
                    obj.Bounder.BR.Pos[1 + INDEX_BASE]) -
                ScrBounder.TL.Pos[1 + INDEX_BASE]) -
            bit.rshift(allegro5.al_get_bitmap_height(obj.ObjType.Image), 1),
            1, 1,
            obj.Angle, 0)
    end
end

--[[

   DrawTriangleTree does the 'hard' work of actually drawing the contents of a
   quad tree. If you've understood how the quad tree is made up and works from
   all the other comments in this file then it is very straightforward and easy
   to follow.

   The only point of interest here is 'framec' - an integer that identifies the
   current frame.

   The problem that necessitates it is that a single screen may cover multiple
   leaf nodes, and that some triangles may be present in more than one of those
   nodes. We don't want to expend energy drawing those triangles twice.

   To resolve this, every triangle keeps a note of the frame in which it was
   last drawn. If that frame is not this frame then it is drawn and that note
   is updated.

   The 'clever' thing about this is that it kills the overdraw without any per
   frame seeding of triangles. The disadvantage is that any triangle which
   doesn't appear on screen for exactly as long as it takes the framec integer
   to overflow then does will not be drawn for one frame.

   Assuming 100 fps and a 32bit CPU, this bug can in the unlikely situation
   that it does occur, only happen after approximately 1.36 years of
   continuous gameplay. It is therefore submitted that it shouldn't be of high
   concern!

   Calculations:

      2^32 = 4,294,967,296
      /100 = 4,294,967.296 seconds
      /60 = 715,827.883 minutes
      /60 = 11,930.465 hours
      /24 = 497.103 days
      /365.25 = 1.36 years

--]]
---@param TriTree QuadTreeNode
---@param Lvl Level
---@param ScrBounder BoundingBox
local function GetQuadTreeVisibilityList(TriTree, Lvl, ScrBounder)
    --[[

      if the view window doesn't overlap this node then do nothing

    --]]
    if Separated(TriTree.Bounder, ScrBounder) then
        return
    end

    --[[

      if this node has children, consider them instead

    --]]
    if TriTree.Children then
        local c = 4 ---@type integer
        while c ~= 0 do
            c = c - 1
            GetQuadTreeVisibilityList(TriTree.Children[c + INDEX_BASE], Lvl, ScrBounder)
        end
    else
        --[[

         otherwise, add to draw list

       --]]
        TriTree.Next = Lvl.VisibleList
        Lvl.VisibleList = TriTree
    end
end

---@param Lvl Level
---@param ScrBounder BoundingBox
---@param framec integer
---@param PostContents boolean
local function DrawQuadTreePart(Lvl, ScrBounder, framec, PostContents)
    --[[ go through each node drawing background details - objects first, then polygons, finally edges --]]
    local Visible = Lvl.VisibleList ---@type QuadTreeNode?
    while Visible do
        --[[

         objects

       --]]
       ---@type Container?
        local Thing = (function() if PostContents then return Visible.PostContents else return Visible.Contents end end)()
        while Thing and Thing.Type == OBJECT do
            if Thing.Content.O.LastFrame ~= framec then
                DrawObject(Thing.Content.O, ScrBounder)
                Thing.Content.O.LastFrame = framec
            end
            Thing = Thing.Next ---@type Container?
        end

        local TriStart = Thing
        while Thing do
            if Thing.Content.T.LastFrame ~= framec then
                DrawTriangle(Thing.Content.T, ScrBounder)
            end
            Thing = Thing.Next
        end

        --[[

         and add edges that haven't already been drawn this frame, this time
         updating the note of the last frame in which this triangle was
         drawn

       --]]
        Thing = TriStart
        while Thing do
            if Thing.Content.T.LastFrame ~= framec then
                DrawTriEdge(Thing.Content.T, ScrBounder)
                Thing.Content.T.LastFrame = framec
            end
            Thing = Thing.Next ---@type Container?
        end

        Visible = Visible.Next ---@type QuadTreeNode?
    end
end

---@param Lvl Level
---@param TriTree QuadTreeNode
---@param ScrBounder BoundingBox
---@param framec integer
local function BeginQuadTreeDraw(Lvl, TriTree, ScrBounder, framec)
    --[[ compile list of visible nodes --]]
    Lvl.VisibleList = nil
    GetQuadTreeVisibilityList(TriTree, Lvl, ScrBounder)
    DrawQuadTreePart(Lvl, ScrBounder, framec, false)
end
exports.BeginQuadTreeDraw = BeginQuadTreeDraw

---@param Lvl Level
---@param ScrBounder BoundingBox
---@param framec integer
local function EndQuadTreeDraw(Lvl, ScrBounder, framec)
    DrawQuadTreePart(Lvl, ScrBounder, framec, true)
end
exports.EndQuadTreeDraw = EndQuadTreeDraw

--[[

   FUNCTIONS FOR ADDING CONTENT

--]]
local MAX_COLL = 200
local MAX_DISP = 50

--[[

   AddTriangle and AddEdge are both very similar indeed and just package the
   new triangle or edge into a 'Container' so that the AddContent function
   knows how to deal with them in a unified manner.

--]]
---@param level Level
---@param NewTri Triangle
local function AddTriangle(level, NewTri)
    local Cont = Container()

    Cont.Content.T = NewTri
    Cont.Type = TRIANGLE
    AddContent(level.DisplayTree, Cont, MAX_DISP)
end
exports.AddTriangle = AddTriangle

---@param level Level
---@param NewEdge Edge
local function AddEdge(level, NewEdge)
    local Cont = Container()

    Cont.Content.E = NewEdge
    Cont.Type = EDGE
    AddContent(level.CollisionTree, Cont, MAX_COLL)
end
exports.AddEdge = AddEdge

---@param level Level
---@param NewObject Object
---@param DisplayTree boolean
local function AddObject(level, NewObject, DisplayTree)
    local Cont = Container()

    Cont.Content.O = NewObject
    Cont.Type = OBJECT

    if DisplayTree then
        if bit.band(NewObject.Flags, OBJFLAGS_VISIBLE) ~= 0 then
            AddContent(level.DisplayTree, Cont, MAX_DISP)
        end
    else
        if bit.band(NewObject.Flags, FLAGS_COLLIDABLE) ~= 0 then
            AddContent(level.CollisionTree, Cont, MAX_COLL)
        end
    end
end
exports.AddObject = AddObject

--[[

        OrderTree sorts the items stored within Tree so that their lists
        consist of all their non-objects (i.e. triangles or edges) first
        followed by all of their objects.

--]]
---@param Tree QuadTreeNode
local function SplitTree(Tree)
    if Tree.Children then
        local c = 4 ---@type integer
        while c ~= 0 do
            c = c - 1
            SplitTree(Tree.Children[c + INDEX_BASE])
        end
    elseif Tree.Contents then
        local P = Tree.Contents
        Tree.PostContents = nil; Tree.Contents = Tree.PostContents

        while P do
            local PNext = P.Next

            if P.Type == OBJECT then
                if bit.band(P.Content.O.Flags, FLAGS_FOREGROUND) ~= 0 then
                    P.Next = Tree.PostContents
                    Tree.PostContents = P
                else
                    P.Next = Tree.Contents
                    Tree.Contents = P
                end
            else
                if bit.band(bit.bor(P.Content.T.EdgeFlags[0 + INDEX_BASE], bit.bor(P.Content.T.
                    EdgeFlags[1 + INDEX_BASE], P.Content.T.EdgeFlags[2 + INDEX_BASE]))
                    , FLAGS_FOREGROUND) ~= 0 then
                    P.Next = Tree.PostContents
                    Tree.PostContents = P
                else
                    P.Next = Tree.Contents
                    Tree.Contents = P
                end
            end

            P = PNext
        end
    end
end
exports.SplitTree = SplitTree

---@param Tree QuadTreeNode
---@param PostTree boolean
local function OrderTree(Tree, PostTree)
    if Tree.Children then
        local c = 4
        while c ~= 0 do
            c = c - 1
            OrderTree(Tree.Children[c + INDEX_BASE], PostTree)
        end
    else
        ---@type Container?
        local ITree = (function() if PostTree then return Tree.PostContents else return Tree.Contents end end)()

        if ITree then
            --[[ separate object and non-oject lists --]]
            local NonObjects, Objects ---@type Container?, Container?
            local P = ITree ---@type Container?
            while P do
                local PNext = P.Next

                if P.Type == OBJECT then
                    P.Next = Objects
                    Objects = P
                else
                    P.Next = NonObjects
                    NonObjects = P
                end

                P = PNext
            end

            --[[ now reintegrate lists - objects then non-objects --]]
            ITree = Objects

            if PostTree then
                Tree.PostContents = ITree
            else
                Tree.Contents = ITree
            end

            local Prev ---@type Container?
            while ITree do
                Prev = ITree
                ITree = ITree.Next ---@type Container?
            end
            ITree = NonObjects

            if Prev then
                Prev.Next = ITree
            elseif PostTree then
                Tree.PostContents = ITree
            else
                Tree.Contents = ITree
            end
        end
    end
end
exports.OrderTree = OrderTree

return exports
