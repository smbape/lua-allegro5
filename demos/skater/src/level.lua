local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/level.h
--]]

local allegro5_lua = require("allegro5_lua")
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global

local _global = require("global")
local level_alloc ---@module 'level_alloc'
local level_file ---@module 'level_file'
local level_state ---@module 'level_state'
local quadtree = require("quadtree")
local token = require("token")

local NewLevel ---@type fun() : Level

local GetNormal ---@type fun(e: Edge, v1: [number, number], v2: [number, number]) : boolean
local LoadMaterials ---@type fun(NewLev: Level)
local LoadObjects ---@type fun(NewLev: Level)
local LoadObjectTypes ---@type fun(NewLev: Level, radius: integer)
local LoadStats ---@type fun(NewLev: Level)
local LoadTriangles ---@type fun(NewLev: Level, radius: integer)
local LoadVertices ---@type fun(NewLev: Level)

local BorrowState ---@type fun(NewLev?: Level) : LevelState?
local FreeState ---@type fun(State?: LevelState)

exports.init = function()
    level_alloc = require("level_alloc")
    level_file = require("level_file")
    level_state = require("level_state")

    NewLevel = level_alloc.NewLevel

    GetNormal = level_file.GetNormal
    LoadMaterials = level_file.LoadMaterials
    LoadObjects = level_file.LoadObjects
    LoadObjectTypes = level_file.LoadObjectTypes
    LoadStats = level_file.LoadStats
    LoadTriangles = level_file.LoadTriangles
    LoadVertices = level_file.LoadVertices

    BorrowState = level_state.BorrowState
    FreeState = level_state.FreeState

end

local TRIFLAGS_EDGE = quadtree.TRIFLAGS_EDGE
local TRIFLAGS_WIDTH = quadtree.TRIFLAGS_WIDTH

local AddEdge = quadtree.AddEdge
local AddObject = quadtree.AddObject
local AddTriangle = quadtree.AddTriangle
local BeginQuadTreeDraw = quadtree.BeginQuadTreeDraw
local BoundingBox = quadtree.BoundingBox
local EndQuadTreeDraw = quadtree.EndQuadTreeDraw
local FreeQuadTree = quadtree.FreeQuadTree
local OrderTree = quadtree.OrderTree
local SplitTree = quadtree.SplitTree

local INDEX_BASE = 1 -- lua is 1-based indexed

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/level.c
--]]

--[[

   Level.c contains the code for loading levels (which are in an ASCII format
   and parsed with a 'reasonable' degree of intelligence) and preprocessing
   them for game use.

   It can also produce a condensed version of the current level state
   (suitable for saving and loading of games, used elsewhere to retain state
   when display resolution is changed) and includes the main hook for level
   drawing - although this is passed on to quadtree.c as determining visibility
   is really a quadtree function.

   Note that the graphical parts of the level are scaled for the current
   display resolution but the collision / physics parts are never scaled. This
   is so that game behaviour is identical regardless of the display resolution
   and so that if the user changes resolution during a game they don't break
   their game state. The rounding error adjustment algorithms (see Physics.c)
   would not be very likely to survive a scaling of velocity and position and
   the player would likely fall through any platform they may be resting on.

--]]

--[[

   Drawing stuff first. Framec is a count of the current frame number, which
   is a required parameter to the drawing stuff in QuadTree.c - see that file
   for comments on that.

   DispBox is the rectangle that the user expects to be displayed. Note that
   (x, y) are parsed in the same units as the player moves so are scaled here
   into screen co-ordinates.

--]]

local framec = 0 ---@type integer
local DispBox = BoundingBox()

---@param lev Level?
---@param pos [number, number]
local function DrawLevelBackground(lev, pos)
    if not lev then
        return
    end
    local h = 480.0
    local w = _global.screen_width * 480 / _global.screen_height
    framec = framec + 1
    DispBox.TL.Pos[0 + INDEX_BASE] = pos[0 + INDEX_BASE] - w / 2
    DispBox.TL.Pos[1 + INDEX_BASE] = pos[1 + INDEX_BASE] - h / 2
    DispBox.BR.Pos[0 + INDEX_BASE] = DispBox.TL.Pos[0 + INDEX_BASE] + w
    DispBox.BR.Pos[1 + INDEX_BASE] = DispBox.TL.Pos[1 + INDEX_BASE] + h

    BeginQuadTreeDraw(lev, lev.DisplayTree, DispBox, framec)
end
exports.DrawLevelBackground = DrawLevelBackground

---@param lev Level?
local function DrawLevelForeground(lev)
    if not lev then
        return
    end
    EndQuadTreeDraw(lev, DispBox, framec)
end
exports.DrawLevelForeground = DrawLevelForeground


---@param name string
---@return ALLEGRO_BITMAP?
local function ObtainBitmap(name)
    for _, data in ipairs(_global.demo_data) do
        if data.type == "bitmap" and
            data.name == name then
            return data.dat
        end
    end
    return nil
end
exports.ObtainBitmap = ObtainBitmap

---@param name string
---@return ALLEGRO_SAMPLE?
local function ObtainSample(name)
    for _, data in ipairs(_global.demo_data) do
        if data.type == "sample" and
            data.name == name then
            return data.dat
        end
    end
    return nil
end
exports.ObtainSample = ObtainSample

--[[

   A couple of very standard functions - min(a,b) returns the minimum of a and
   b, max(a,b) returns the maximum of a and b. Both have all the usual
   disadvantages of preprocessor macros (e.g. consider what will happen with
   min(a, b++)), but for this code it doesn't matter in the slightest.

--]]

--[[

   The FreeLevel function and associated macros. Just runs through all the data
   structures freeing anything that may have been allocated. Not really worthy
   of extensive comment.

   This function does the freeing for all level related struct types - there is
   no set of C++ equivalent deconstructors

--]]
---@param lvl Level
---@param name '"AllTris"' | "AllEdges" | "AllMats" | "AllObjectTypes" | "AllVerts" | "AllObjects"
---@param sp function
local function FreeList(lvl, name, sp)
    while lvl[name] do
        local Next = lvl[name].Next ---@diagnostic disable-line: no-unknown
        sp(lvl[name])
        lvl[name] = Next ---@diagnostic disable-line: no-unknown
    end
end

local function NoAction(v)
    -- Nothing to do
end

---@param lvl Level?
local function FreeLevel(lvl)
    if not lvl then
        return
    end

    --[[ easy things first --]]
    FreeQuadTree(lvl.DisplayTree)
    FreeQuadTree(lvl.CollisionTree)

    --[[ free the resource lists --]]
    FreeList(lvl, "AllTris", NoAction)
    FreeList(lvl, "AllEdges", NoAction)

    FreeList(lvl, "AllMats", NoAction)
    FreeList(lvl, "AllObjectTypes", NoAction)

    FreeList(lvl, "AllVerts", NoAction)
    FreeList(lvl, "AllObjects", NoAction)

    --[[ finally, free the level structure itself --]]
    FreeState(lvl.InitialState)
end
exports.FreeLevel = FreeLevel

--[[ 01234567890123456789012345678901234567890123456789012345678901234567890123456789 --]]
---@param e1 Edge
---@param e2 Edge
---@param Inter [number, number]
---@param radius integer
---@return boolean
local function CalcIntersection(e1, e2, Inter, radius)
    local d1 =
        (e1.EndPoints[0 + INDEX_BASE].Pos[0 + INDEX_BASE] + radius * e1.a) * e2.a +
        (e1.EndPoints[0 + INDEX_BASE].Pos[1 + INDEX_BASE] + radius * e1.b) * e2.b + e2.c
    local d2 =
        (e1.EndPoints[1 + INDEX_BASE].Pos[0 + INDEX_BASE] + radius * e1.a) * e2.a +
        (e1.EndPoints[1 + INDEX_BASE].Pos[1 + INDEX_BASE] + radius * e1.b) * e2.b + e2.c

    if d1 - d2 == 0 then
        return false
    end

    d1 = d1 / (d1 - d2)
    Inter[0 + INDEX_BASE] =
        e1.EndPoints[0 + INDEX_BASE].Pos[0 + INDEX_BASE] + radius * e1.a +
        d1 * (e1.EndPoints[1 + INDEX_BASE].Pos[0 + INDEX_BASE] - e1.EndPoints[0 + INDEX_BASE].Pos[0 + INDEX_BASE])
    Inter[1 + INDEX_BASE] =
        e1.EndPoints[0 + INDEX_BASE].Pos[1 + INDEX_BASE] + radius * e1.b +
        d1 * (e1.EndPoints[1 + INDEX_BASE].Pos[1 + INDEX_BASE] - e1.EndPoints[0 + INDEX_BASE].Pos[1 + INDEX_BASE])

    return true
end

---@param NewLev Level
---@param radius integer
local function FixVerts(NewLev, radius)
    local v = NewLev.AllVerts ---@type Vertex?

    while v do
        if v.Edges[1 + INDEX_BASE] then
            --[[ position normal at intersection of two connected edges --]]
            if not CalcIntersection(v.Edges[0 + INDEX_BASE], v.Edges[1 + INDEX_BASE], v.Normal, radius) then
                v.Normal[0 + INDEX_BASE] = v.Pos[0 + INDEX_BASE] + v.Edges[0 + INDEX_BASE].a * radius
                v.Normal[1 + INDEX_BASE] = v.Pos[1 + INDEX_BASE] + v.Edges[0 + INDEX_BASE].b * radius
            end
        elseif v.Edges[0 + INDEX_BASE] then
            --[[ position normal as a straight projection from v->Edge + INDEX_BASEs[0] --]]
            local Direction = -1.0

            if v.Edges[0 + INDEX_BASE].EndPoints[0 + INDEX_BASE] == v then
                Direction = 1.0
            end

            v.Normal[0 + INDEX_BASE] =
                v.Pos[0 + INDEX_BASE] + v.Edges[0 + INDEX_BASE].a * radius +
                radius * Direction * v.Edges[0 + INDEX_BASE].b
            v.Normal[1 + INDEX_BASE] =
                v.Pos[1 + INDEX_BASE] + v.Edges[0 + INDEX_BASE].b * radius -
                radius * Direction * v.Edges[0 + INDEX_BASE].a
        end

        v = v.Next ---@type Vertex?
    end
end

---@param NewLev Level
---@param radius integer
---@return boolean
local function FixEdges(NewLev, radius)
    local Prev = NewLev ---@type Level|Edge

    local e = NewLev.AllEdges
    local NotFinished = false
    while e do
        --[[ check whether edge is now the wrong way around, and if so set NotFinished --]]
        local a, b = e.a, e.b
        local Failed =
            GetNormal(e, e.EndPoints[0 + INDEX_BASE].Normal,
                e.EndPoints[1 + INDEX_BASE].Normal)

        if Failed or (e.a * a + e.b * b) < 0 then
            NotFinished = true

            --[[ fix edge pointers --]]
            ---@type Edge?
            local EdgePtr =
                (function()
                    if (e.EndPoints[1 + INDEX_BASE].Edges[0 + INDEX_BASE] == e) then
                        return e.EndPoints[1 + INDEX_BASE].Edges[1 + INDEX_BASE]
                    else
                        return e.EndPoints[1 + INDEX_BASE].Edges[0 + INDEX_BASE]
                    end
                end)()

            if e.EndPoints[0 + INDEX_BASE].Edges[0 + INDEX_BASE] == e then
                if not EdgePtr then
                    e.EndPoints[0 + INDEX_BASE].Edges[0 + INDEX_BASE] = e.EndPoints[0 + INDEX_BASE].Edges[1 + INDEX_BASE]
                    e.EndPoints[0 + INDEX_BASE].Edges[1 + INDEX_BASE] = nil
                else
                    e.EndPoints[0 + INDEX_BASE].Edges[0 + INDEX_BASE] = EdgePtr
                end
            else
                e.EndPoints[0 + INDEX_BASE].Edges[1 + INDEX_BASE] = EdgePtr
            end

            if EdgePtr then
                if EdgePtr.EndPoints[0 + INDEX_BASE] == e.EndPoints[1 + INDEX_BASE] then
                    EdgePtr.EndPoints[0 + INDEX_BASE] = e.EndPoints[0 + INDEX_BASE]
                else
                    EdgePtr.EndPoints[1 + INDEX_BASE] = e.EndPoints[0 + INDEX_BASE]
                end
            end

            e.EndPoints[1 + INDEX_BASE].Edges[1 + INDEX_BASE] = nil; e.EndPoints[1 + INDEX_BASE].Edges[0 + INDEX_BASE] = e.EndPoints[1 + INDEX_BASE].Edges[1 + INDEX_BASE]

            --[[ unlink & free --]]
            EdgePtr = e
            if Prev == NewLev then
                NewLev.AllEdges = e.Next
            else
                Prev.Next = e.Next
            end
            e = e.Next
            -- free((void *)EdgePtr)

            if not e then
                break
            end
        end

        Prev = e
        e = e.Next
    end

    return NotFinished
end

--[[

   AddEdges calculates the axis aligned bounding boxes of all
   edges and inserts them into the collision tree

--]]
---@param NewLev Level
local function AddEdges(NewLev)
    local e = NewLev.AllEdges ---@type Edge?

    while e do
        --[[ calculate AABB for this edge --]]
        e.Bounder.TL.Pos[0 + INDEX_BASE] =
            math.min(e.EndPoints[0 + INDEX_BASE].Normal[0 + INDEX_BASE], e.EndPoints[1 + INDEX_BASE].Normal[0 + INDEX_BASE]) - 0.05
        e.Bounder.TL.Pos[1 + INDEX_BASE] =
            math.min(e.EndPoints[0 + INDEX_BASE].Normal[1 + INDEX_BASE], e.EndPoints[1 + INDEX_BASE].Normal[1 + INDEX_BASE]) - 0.05

        e.Bounder.BR.Pos[0 + INDEX_BASE] =
            math.max(e.EndPoints[0 + INDEX_BASE].Normal[0 + INDEX_BASE], e.EndPoints[1 + INDEX_BASE].Normal[0 + INDEX_BASE]) + 0.05
        e.Bounder.BR.Pos[1 + INDEX_BASE] =
            math.max(e.EndPoints[0 + INDEX_BASE].Normal[1 + INDEX_BASE], e.EndPoints[1 + INDEX_BASE].Normal[1 + INDEX_BASE]) + 0.05

        --[[ insert into quadtree --]]
        AddEdge(NewLev, e)

        e = e.Next ---@type Edge?
    end
end

--[[

   ScaleAndAddObjects calculates a collision box for the
   object, adds it to the collision tree then scales the
   box for the current display resolution before adding to
   the display tree

--]]
---@param Lvl Level
local function ScaleAndAddObjects(Lvl)
    --double Scaler = (float)global.screen_height / 480.0f;

    for _, O in ipairs(Lvl.AllObjects) do
        --[[ generate bounding box for collisions (i.e. no scaling yet) --]]
        O.Bounder.BR.Pos[0 + INDEX_BASE] = O.Pos[0 + INDEX_BASE] + O.ObjType.Radius
        O.Bounder.BR.Pos[1 + INDEX_BASE] = O.Pos[1 + INDEX_BASE] + O.ObjType.Radius
        O.Bounder.TL.Pos[0 + INDEX_BASE] = O.Pos[0 + INDEX_BASE] - O.ObjType.Radius
        O.Bounder.TL.Pos[1 + INDEX_BASE] = O.Pos[1 + INDEX_BASE] - O.ObjType.Radius

        --[[ insert into collisions tree --]]
        AddObject(Lvl, O, false)

        --[[ scale bounding box to get visual position --]]
        --[[O->Bounder.BR.Po + INDEX_BASEs[0] *= Scaler;
      O->Bounder.BR.Po + INDEX_BASEs[1] *= Scaler;
      O->Bounder.TL.Po + INDEX_BASEs[0] *= Scaler;
      O->Bounder.TL.Po + INDEX_BASEs[1] *= Scaler;--]]

        --[[ insert into display tree --]]
        AddObject(Lvl, O, true)

        --[[ move along linked lists --]]
    end
end

--[[

   AddTriangles takes the now fully processed list of world
   triangles, calculates their bounding boxes (allowing for any
   edge trim) and inserts them into the display tree

--]]
---@param Lvl Level
local function AddTriangles(Lvl)
    local Tri = Lvl.AllTris ---@type Triangle?

    while Tri do
        local c = 3 ---@integer

        --[[ determine axis aligned bounding box --]]
        Tri.Bounder.BR.Pos[0 + INDEX_BASE] = Tri.Edges[0 + INDEX_BASE].Pos[0 + INDEX_BASE]; Tri.Bounder.TL.Pos[0 + INDEX_BASE] = Tri.Bounder.BR.Pos[0 + INDEX_BASE]
        Tri.Bounder.BR.Pos[1 + INDEX_BASE] = Tri.Edges[0 + INDEX_BASE].Pos[1 + INDEX_BASE]; Tri.Bounder.TL.Pos[1 + INDEX_BASE] = Tri.Bounder.BR.Pos[1 + INDEX_BASE]

        while c ~= 0 do
            c = c - 1
            local lc = c - 1

            if lc < 0 then
                lc = 2
            end

            --[[ check if this x expands the bounding box either leftward or rightward --]]
            if Tri.Edges[c + INDEX_BASE].Pos[0 + INDEX_BASE] < Tri.Bounder.TL.Pos[0 + INDEX_BASE] then
                Tri.Bounder.TL.Pos[0 + INDEX_BASE] = Tri.Edges[c + INDEX_BASE].Pos[0 + INDEX_BASE]
            end
            if Tri.Edges[c + INDEX_BASE].Pos[0 + INDEX_BASE] > Tri.Bounder.BR.Pos[0 + INDEX_BASE] then
                Tri.Bounder.BR.Pos[0 + INDEX_BASE] = Tri.Edges[c + INDEX_BASE].Pos[0 + INDEX_BASE]
            end

            --[[ check y --]]
            if bit.band(Tri.EdgeFlags[c + INDEX_BASE], TRIFLAGS_EDGE) ~= 0
                or bit.band(Tri.EdgeFlags[lc + INDEX_BASE], TRIFLAGS_EDGE) ~= 0 then
                if Tri.Edges[c + INDEX_BASE].Pos[1 + INDEX_BASE] -
                    (bit.band(Tri.EdgeFlags[c + INDEX_BASE], TRIFLAGS_WIDTH)) < Tri.Bounder.TL.Pos[1 + INDEX_BASE] then
                    Tri.Bounder.TL.Pos[1 + INDEX_BASE] =
                        Tri.Edges[c + INDEX_BASE].Pos[1 + INDEX_BASE] -
                        (bit.band(Tri.EdgeFlags[c + INDEX_BASE], TRIFLAGS_WIDTH))
                end
                if Tri.Edges[c + INDEX_BASE].Pos[1 + INDEX_BASE] + bit.band(Tri.EdgeFlags[c + INDEX_BASE], TRIFLAGS_WIDTH) >
                    Tri.Bounder.BR.Pos[1 + INDEX_BASE] then
                    Tri.Bounder.BR.Pos[1 + INDEX_BASE] =
                        Tri.Edges[c + INDEX_BASE].Pos[1 + INDEX_BASE] +
                        bit.band(Tri.EdgeFlags[c + INDEX_BASE], TRIFLAGS_WIDTH)
                end
            else
                if Tri.Edges[c + INDEX_BASE].Pos[1 + INDEX_BASE] < Tri.Bounder.TL.Pos[1 + INDEX_BASE] then
                    Tri.Bounder.TL.Pos[1 + INDEX_BASE] = Tri.Edges[c + INDEX_BASE].Pos[1 + INDEX_BASE]
                end
                if Tri.Edges[c + INDEX_BASE].Pos[1 + INDEX_BASE] > Tri.Bounder.BR.Pos[1 + INDEX_BASE] then
                    Tri.Bounder.BR.Pos[1 + INDEX_BASE] = Tri.Edges[c + INDEX_BASE].Pos[1 + INDEX_BASE]
                end
            end
        end

        --[[ insert into tree --]]
        AddTriangle(Lvl, Tri)

        --[[ move along linked list --]]
        Tri = Tri.Next ---@type Triangle?
    end
end

--[[

   GetLevelError returns a textual description of any error
   that has occurred. If no error has occurred it will
   slightly confusingly return "Unspecified error at line
   <line count for file>"

   Appends "Level load - " to the start of whatever text
   may already have been provided

--]]
---@return string?
local function GetLevelError()
    if not token.ErrorText then
        token.ErrorText = string.format("Unspecified error at line %d",
            token.Lines)
    end

    local LocTemp = token.ErrorText
    token.ErrorText = string.format("Level load - %s", LocTemp)
    return token.ErrorText
end
exports.GetLevelError = GetLevelError

--[[

   LoadLevel is called by other parts of the program and returns
   either a complete level structure or NULL indicating error, in
   which case GetLevelError will return a textual description
   of the error.

   Parameters are 'name' - the file name of the level and 'radius'
   - the collision size of the player for collision tree building

--]]
---@param name string?
---@param radius integer
---@return Level?
local function LoadLevel(name, radius)
    if not name then
        return nil
    end

    local NewLev ---@type Level?
    token.ErrorText = nil --[[ set ErrorText to be a zero length string
                             so that it will be obvious later if anything has set the error flag
                             but not produced a verbose explanation of the error --]]
    token.Error = false --[[ reset error flag as no error has occurred yet --]]
    token.Lines = 1 --[[ first line is line 1 --]]

    --[[ attempt to open named level file --]]
    local file = io.open(name, "r")
    local input = file
    token.input = input

    local function _error()
        --[[ close input file --]]
        if file then
            file:close()
        end

        if NewLev then
            FreeLevel(NewLev)
        end

        return nil
    end

    if not input then
        token.ErrorText = string.format("Unable to load %s", name)
        return _error()
    end

    --[[ allocate and initially set up new level structure --]]
    NewLev = NewLevel()

    --[[ load materials, vertices & triangles in that order --]]
    LoadMaterials(NewLev)
    if token.Error then
        return _error()
    end
    LoadVertices(NewLev)
    if token.Error then
        return _error()
    end
    LoadTriangles(NewLev, radius)
    if token.Error then
        return _error()
    end

    --[[ do a repeat 'fix' of vertices and fix of edges until we have
      no edge errors - see algorithm descriptions elsewhere in this
      file --]]
    repeat
        FixVerts(NewLev, radius)
    until not FixEdges(NewLev, radius)

    --[[ now that edges are al_fixed, add them to the collision tree --]]
    AddEdges(NewLev)

    --[[ load ordinary object types --]]
    LoadObjectTypes(NewLev, radius)
    if token.Error then
        return _error()
    end

    --[[ load special case object: door --]]
    NewLev.DoorOpen = ObtainBitmap("dooropen")
    if not NewLev.DoorOpen then
        token.ErrorText = "Unable to obtain dooropen sprite"
        return _error()
    end
    NewLev.DoorShut = ObtainBitmap("doorshut")
    if not NewLev.DoorShut then
        token.ErrorText = "Unable to obtain doorshut sprite"
        return _error()
    end
    NewLev.Door.Image = NewLev.DoorShut
    NewLev.Door.CollectNoise = ObtainSample("dooropen")
    NewLev.Door.Radius = 14 + radius

    --[[ load objects --]]
    NewLev.TotalObjects = 0
    LoadObjects(NewLev)
    if token.Error then
        return _error()
    end

    --[[ complete display tree additions --]]
    AddTriangles(NewLev)
    ScaleAndAddObjects(NewLev)

    --[[ order things for drawing --]]
    SplitTree(NewLev.DisplayTree)
    OrderTree(NewLev.DisplayTree, false)
    OrderTree(NewLev.DisplayTree, true)
    OrderTree(NewLev.CollisionTree, false)

    --[[ load static level stuff - player start pos, etc --]]
    LoadStats(NewLev)
    if token.Error then
        return _error()
    end

    --[[ make a copy of the initial state --]]
    NewLev.InitialState = BorrowState(NewLev)

    --[[ return level --]]
    return NewLev
end
exports.LoadLevel = LoadLevel

return exports
