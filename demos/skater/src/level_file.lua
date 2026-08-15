local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/level_file.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local _global = require("global")
local level = require("level")
local level_alloc = require("level_alloc")
local quadtree = require("quadtree")
local token = require("token")

local ObtainBitmap = level.ObtainBitmap
local ObtainSample = level.ObtainSample

local NewEdge = level_alloc.NewEdge
local NewMaterial = level_alloc.NewMaterial
local NewObject = level_alloc.NewObject
local NewObjectType = level_alloc.NewObjectType
local NewTriangle = level_alloc.NewTriangle
local NewVertex = level_alloc.NewVertex

local TK_CLOSEBRACE = token.TK_CLOSEBRACE
local TK_COMMA = token.TK_COMMA
local TK_NUMBER = token.TK_NUMBER
local TK_OPENBRACE = token.TK_OPENBRACE
local TK_STRING = token.TK_STRING

local FLAGS_COLLIDABLE = quadtree.FLAGS_COLLIDABLE
local FLAGS_FOREGROUND = quadtree.FLAGS_FOREGROUND
local OBJFLAGS_DOOR = quadtree.OBJFLAGS_DOOR
local TRIFLAGS_EDGE = quadtree.TRIFLAGS_EDGE

local ExpectToken = token.ExpectToken
local GetToken = token.GetToken
local Token = token.Token

local sqrt = math.sqrt

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/level_file.c
--]]

--[[

   Routines related to the initial reading of level data - heavily connected to
   tkeniser.c. Defines the grammar that level files should use.

   Also includes a simple function for obtaining the equation of a line and some
   other bits to do with data initialisation that flows straight from level data

--]]


--[[

   LoadMaterials loads the list of materials according to the following grammar:

      fillname -> string
      edgename -> string
      materal -> { fillname, edgename }
      material list -> { material* }

--]]
---@param NewLev Level
local function LoadMaterials(NewLev)
    local Prev = NewLev ---@type Level|Material

    ExpectToken(TK_OPENBRACE)
    while 1 do
        GetToken()

        if Token.Type == TK_CLOSEBRACE then
            return
        elseif Token.Type == TK_OPENBRACE then
            local NewMatPtr = NewMaterial()

            ExpectToken(TK_STRING)
            NewMatPtr.Fill = ObtainBitmap(Token.Text)
            if not NewMatPtr.Fill then
                token.Error = true
                token.ErrorText = string.format("Could not load material fill %s at line %d",
                    Token.Text, token.Lines)
                return
            end

            ExpectToken(TK_COMMA)
            ExpectToken(TK_STRING)

            local TmpEdge = ObtainBitmap(Token.Text)
            if os.getenv("DEMO_USE_ALLEGRO_GL") ~= 1 then
                NewMatPtr.Edge = TmpEdge
            end
            if not TmpEdge then
                token.Error = true
                token.ErrorText = string.format("Could not load material edge %s at line %d",
                    Token.Text, token.Lines)
                return
            end

            ExpectToken(TK_COMMA)
            ExpectToken(TK_NUMBER)
            NewMatPtr.Friction = Token.FQuantity

            ExpectToken(TK_CLOSEBRACE)
            if Prev == NewLev then
                NewLev.AllMats = NewMatPtr
            else
                Prev.Next = NewMatPtr
            end

            Prev = NewMatPtr
        else
            token.Error = true
            return
        end
    end
end
exports.LoadMaterials = LoadMaterials

--[[

   LoadVertices loads the list of vertices according to the following grammar:

      xpos -> number
      ypos -> number
      vertex -> { xpos, ypos }
      vertex list -> { vertex* }

--]]
--- @param NewLev Level
local function LoadVertices(NewLev)
    local Prev = NewLev ---@type Level|Vertex

    ExpectToken(TK_OPENBRACE)
    while 1 do
        GetToken()

        if Token.Type == TK_CLOSEBRACE then
            return
        elseif Token.Type == TK_OPENBRACE then
            local NewVertPtr = NewVertex()

            ExpectToken(TK_NUMBER)
            NewVertPtr.Pos[0 + INDEX_BASE] = Token.FQuantity

            ExpectToken(TK_COMMA)
            ExpectToken(TK_NUMBER)
            NewVertPtr.Pos[1 + INDEX_BASE] = Token.FQuantity

            ExpectToken(TK_CLOSEBRACE)

            if Prev == NewLev then
                NewLev.AllVerts = NewVertPtr
            else
                Prev.Next = NewVertPtr
            end

            Prev = NewVertPtr
        else
            token.Error = true
            return
        end
    end
end
exports.LoadVertices = LoadVertices

--[[

   GetVert loads a single vertex reference as part of the LoadTriangles routine.
   Grammar is:

      edge height -> number
      reference -> number
      flags -> "edge" | "collidable" | "foreground"
      vertex reference -> { reference, edge height [, flags] }

--]]
---@param NewLev Level
---@param t Triangle
---@param c integer
local function GetVert(NewLev, t, c)
    ExpectToken(TK_OPENBRACE)

    ExpectToken(TK_NUMBER)
    t.Edges[c + INDEX_BASE] = NewLev.AllVerts
    while t.Edges[c + INDEX_BASE] and (function()
            local IQuantity = Token.IQuantity
            Token.IQuantity = Token.IQuantity - 1
            return IQuantity
        end)() ~= 0 do
        t.Edges[c + INDEX_BASE] = t.Edges[c + INDEX_BASE].Next
    end

    if Token.IQuantity ~= -1 then
        token.Error = true
        token.ErrorText = string.format("Unknown vertex referenced at line %d", token.Lines)
        return
    end
    ExpectToken(TK_COMMA)

    ExpectToken(TK_NUMBER)
    t.EdgeFlags[c + INDEX_BASE] = math.floor((Token.IQuantity * _global.screen_height) / 480)

    GetToken()

    if Token.Type == TK_COMMA then
        local Finished = false

        while not Finished do
            GetToken()

            if Token.Type == TK_CLOSEBRACE then
                Finished = true
            elseif Token.Type == TK_STRING then
                if Token.Text == "edge" then
                    t.EdgeFlags[c + INDEX_BASE] = bit.bor(t.EdgeFlags[c + INDEX_BASE], TRIFLAGS_EDGE)
                end
                if Token.Text == "collidable" then
                    t.EdgeFlags[c + INDEX_BASE] = bit.bor(t.EdgeFlags[c + INDEX_BASE], FLAGS_COLLIDABLE)
                end
                if Token.Text == "foreground" then
                    t.EdgeFlags[c + INDEX_BASE] = bit.bor(t.EdgeFlags[c + INDEX_BASE], FLAGS_FOREGROUND)
                end
            else
                token.Error = true
                return
            end
        end
    elseif Token.Type == TK_CLOSEBRACE then

    else
        token.Error = true
        return
    end
end

--[[

   GetNormal is a function that doesn't read anything from a file but calculates
   an edge normal for 'e' based on end points 'v1' and 'v2'

--]]
---@param e Edge
---@param v1 [number, number]
---@param v2 [number, number]
---@return boolean
local function GetNormal(e, v1, v2)
    --[[ get line normal --]]
    local length = 0

    e.a = v2[1 + INDEX_BASE] - v1[1 + INDEX_BASE]
    e.b = -(v2[0 + INDEX_BASE] - v1[0 + INDEX_BASE])

    --[[ make line normal unit length --]]
    length = sqrt(e.a * e.a + e.b * e.b)
    if length < 1.0 then
        return true
    end
    e.a = e.a / (length)
    e.b = e.b / (length)

    --[[ calculate distance of line from origin --]]
    e.c = -(v1[0 + INDEX_BASE] * e.a + v1[1 + INDEX_BASE] * e.b)
    return false
end
exports.GetNormal = GetNormal

--[[

   InitEdge intialises edges, which means calculating the 'expanded' edge equation
   (i.e. one moved away from the real edge by 'radius' units) and making a note at
   both end vertices of the edge they meet

--]]
---@param e Edge
---@param radius integer
local function InitEdge(e, radius)
    --[[ get edge normal --]]
    GetNormal(e, e.EndPoints[0 + INDEX_BASE].Pos, e.EndPoints[1 + INDEX_BASE].Pos)

    --[[ calculate distance to line from origin --]]
    e.c = e.c - (radius * (e.a * e.a + e.b * e.b))

    --[[ link edge as necessary --]]
    if not e.EndPoints[0 + INDEX_BASE].Edges[0 + INDEX_BASE] then
        e.EndPoints[0 + INDEX_BASE].Edges[0 + INDEX_BASE] = e
    else
        e.EndPoints[0 + INDEX_BASE].Edges[1 + INDEX_BASE] = e
    end
    if not e.EndPoints[1 + INDEX_BASE].Edges[0 + INDEX_BASE] then
        e.EndPoints[1 + INDEX_BASE].Edges[0 + INDEX_BASE] = e
    else
        e.EndPoints[1 + INDEX_BASE].Edges[1 + INDEX_BASE] = e
    end
end

--[[

   LoadTriangles loads a triangle list, using GetVert as required. Grammar is:

      vertex reference -> (see GetVert commentary)
      material reference -> number
      triangle ->        { vertex reference, vertex reference, vertex reference,
                              material reference }
      triangle list -> { triangle* }

--]]
---@param NewLev Level
---@param radius integer
local function LoadTriangles(NewLev, radius)
    local Tri ---@type Triangle
    local NextEdge ---@type Edge
    local c = 0 ---@type integer

    ExpectToken(TK_OPENBRACE)
    while 1 do
        GetToken()

        if Token.Type == TK_CLOSEBRACE then
            return
        elseif Token.Type == TK_OPENBRACE then
            Tri = NewTriangle()

            --[[ read vertex pointers & edge flags --]]
            GetVert(NewLev, Tri, 0)
            ExpectToken(TK_COMMA)
            GetVert(NewLev, Tri, 1)
            ExpectToken(TK_COMMA)
            GetVert(NewLev, Tri, 2)
            ExpectToken(TK_COMMA)

            --[[ read material reference and store correct pointer --]]
            ExpectToken(TK_NUMBER)

            Tri.Material = NewLev.AllMats
            while Tri.Material and (function()
                    local IQuantity = Token.IQuantity
                    Token.IQuantity = Token.IQuantity - 1
                    return IQuantity
                end)() ~= 0 do
                Tri.Material = Tri.Material.Next
            end
            if Token.IQuantity ~= -1 then
                token.Error = true
                token.ErrorText = string.format("Unknown material referenced at line %d", token.Lines)
                return
            end

            --[[ expect end of this triangle --]]
            ExpectToken(TK_CLOSEBRACE)

            --[[ insert new triangle into total level list --]]
            Tri.Next = NewLev.AllTris
            NewLev.AllTris = Tri

            --[[ generate edges --]]
            c = 3
            while c ~= 0 do
                c = c - 1 ---@type integer
                if bit.band(Tri.EdgeFlags[c + INDEX_BASE], FLAGS_COLLIDABLE) ~= 0 then
                    NextEdge = NewLev.AllEdges
                    NewLev.AllEdges = NewEdge()
                    NewLev.AllEdges.Material = Tri.Material
                    NewLev.AllEdges.Next = NextEdge

                    NewLev.AllEdges.EndPoints[0 + INDEX_BASE] = Tri.Edges[c + INDEX_BASE]
                    NewLev.AllEdges.EndPoints[1 + INDEX_BASE] = Tri.Edges[(c + 1) % 3 + INDEX_BASE]

                    InitEdge(NewLev.AllEdges, radius)
                end
            end
        else
            token.Error = true
            return
        end
    end
end
exports.LoadTriangles = LoadTriangles

--[[

   LoadObjectTypes loads a list of object types. Grammar is:

      image name -> string
      collection noise -> string
      object type -> { image name, collection noise }
      object type list -> { object type* }

--]]
---@param NewLev Level
---@param radius integer
local function LoadObjectTypes(NewLev, radius)
    local Prev = NewLev ---@type Level|ObjectType

    ExpectToken(TK_OPENBRACE)
    while 1 do
        GetToken()

        if Token.Type == TK_CLOSEBRACE then
            return
        elseif Token.Type == TK_OPENBRACE then
            local NewObjectPtr = NewObjectType()

            ExpectToken(TK_STRING)
            NewObjectPtr.Image = ObtainBitmap(Token.Text)
            if not NewObjectPtr.Image then
                token.Error = true
                token.ErrorText = string.format("Could not load object image %s at line %d",
                    Token.Text, token.Lines)
                return
            end
            local w = allegro5.al_get_bitmap_width(NewObjectPtr.Image)
            local h = allegro5.al_get_bitmap_height(NewObjectPtr.Image)
            NewObjectPtr.Radius = (function() if w > h then return w else return h end end)()
            NewObjectPtr.Radius = NewObjectPtr.Radius + radius

            ExpectToken(TK_COMMA)
            ExpectToken(TK_STRING)

            --[[ this doesn't generate an error as it is permissible to have objects that don't make a noise when collected --]]
            NewObjectPtr.CollectNoise = ObtainSample(Token.Text)

            ExpectToken(TK_CLOSEBRACE)
            if Prev == NewLev then
                NewLev.AllObjectTypes = NewObjectPtr
            else
                Prev.Next = NewObjectPtr
            end
            Prev = NewObjectPtr
        else
            token.Error = true
            return
        end
    end
end
exports.LoadObjectTypes = LoadObjectTypes

--[[

   LoadObjects loads a list of objects. Grammar is:

      object pos x -> number
      object pos y -> number
      object type -> number
      flags -> "collidable" | "foreground"
      object -> { object pos x, object pos y, object type [, flags] }
      object list -> { object* }

--]]
---@param NewLev Level
local function LoadObjects(NewLev)
    local Finished = false

    ExpectToken(TK_OPENBRACE)
    while 1 do
        GetToken()

        if Token.Type == TK_CLOSEBRACE then
            return
        elseif Token.Type == TK_OPENBRACE then
            local Obj = NewObject()
            NewLev.TotalObjects = NewLev.TotalObjects + 1

            --[[ read location --]]
            ExpectToken(TK_NUMBER)
            Obj.Pos[0 + INDEX_BASE] = Token.FQuantity
            ExpectToken(TK_COMMA)
            ExpectToken(TK_NUMBER)
            Obj.Pos[1 + INDEX_BASE] = Token.FQuantity
            ExpectToken(TK_COMMA)

            --[[ read angle, convert into Allegro format --]]
            ExpectToken(TK_NUMBER)
            Obj.Angle = Token.FQuantity
            ExpectToken(TK_COMMA)

            --[[ read object type, manipulate pointer --]]
            ExpectToken(TK_NUMBER)
            if Token.IQuantity >= 0 then
                Obj.ObjType = NewLev.AllObjectTypes
                while Obj.ObjType and (function()
                        local IQuantity = Token.IQuantity
                        Token.IQuantity = Token.IQuantity - 1
                        return IQuantity
                    end)() ~= 0 do
                    Obj.ObjType = Obj.ObjType.Next
                end

                if Token.IQuantity ~= -1 then
                    token.Error = true
                    token.ErrorText = string.format("Unknown object referenced at line %d", token.Lines)
                    return
                end
            else
                --[[ this is the door - a hard coded type --]]
                Obj.ObjType = NewLev.Door
                Obj.Flags = bit.bor(Obj.Flags, OBJFLAGS_DOOR)
                NewLev.TotalObjects = NewLev.TotalObjects - 1
            end

            --[[ parse any flags that may exist --]]
            GetToken()

            if Token.Type == TK_COMMA then
                Finished = false
                while not Finished do
                    GetToken()

                    if Token.Type == TK_CLOSEBRACE then
                        Finished = true
                    elseif Token.Type == TK_STRING then
                        if Token.Text == "collidable" then
                            Obj.Flags = bit.bor(Obj.Flags, FLAGS_COLLIDABLE)
                        end
                        if Token.Text == "foreground" then
                            Obj.Flags = bit.bor(Obj.Flags, FLAGS_FOREGROUND)
                        end
                    else
                        token.Error = true
                        return
                    end
                end
            elseif Token.Type == TK_CLOSEBRACE then

            else
                token.Error = true
                return
            end

            --[[ thread into list --]]
            NewLev.AllObjects[#NewLev.AllObjects + 1] = Obj
        else
            token.Error = true
            return
        end
    end
end
exports.LoadObjects = LoadObjects

--[[

   LoadStats loads some special variables. Grammar is:

      player start x -> number
      player start y -> number
      required number of objects -> number
      stats -> { player start x, player start y, required number of objects }

--]]
---@param NewLev Level
local function LoadStats(NewLev)
    ExpectToken(TK_OPENBRACE)

    ExpectToken(TK_NUMBER)
    NewLev.PlayerStartPos[0 + INDEX_BASE] = Token.FQuantity
    ExpectToken(TK_COMMA)
    ExpectToken(TK_NUMBER)
    NewLev.PlayerStartPos[1 + INDEX_BASE] = Token.FQuantity
    ExpectToken(TK_COMMA)

    ExpectToken(TK_NUMBER)
    NewLev.ObjectsRequired = Token.IQuantity
    ExpectToken(TK_CLOSEBRACE)
end
exports.LoadStats = LoadStats

return exports
