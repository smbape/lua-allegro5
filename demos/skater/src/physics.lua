local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/physics.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local anim = require("anim")
local game = require("game")
local quadtree = require("quadtree")

local AdvanceAnimation = anim.AdvanceAnimation

local KEYFLAG_FLIP = game.KEYFLAG_FLIP
local KEYFLAG_JUMP = game.KEYFLAG_JUMP
local KEYFLAG_JUMP_ISSUED = game.KEYFLAG_JUMP_ISSUED
local KEYFLAG_JUMPING = game.KEYFLAG_JUMPING
local KEYFLAG_LEFT = game.KEYFLAG_LEFT
local KEYFLAG_RIGHT = game.KEYFLAG_RIGHT

local EDGE = quadtree.EDGE

local GetCollisionNode = quadtree.GetCollisionNode

local atan2 = math.atan2 or math.atan ---@diagnostic disable-line: deprecated
local fabs = math.abs

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/physics.c
--]]

--[[

   FixUp is called when the player has collided with 'something' and takes
   the current player's velocity and the vector normal of whatever has been
   hit as arguments.

   It's job is primarily to remove whatever proportion of the velocity is
   running into the surface. This means that the player's velocity ends
   up running at a right angle to the normal.

   Think of a perfectly unbouncy ball falling onto a horizontal floor.
   It's vertical velocity is instantly zero'd, but its horizontal velocity
   is unaffected.

   FixUp does this same thing for surfaces that aren't horizontal using
   the dot product.

   As a secondary function it returns the magnitude of force it has away,
   which can be used to pick a 'thud' sound effect and also for friction
   calculations

--]]
---@param vec [number, number]
---@param normalx number
---@param normaly number
---@return number
local function FixUp(vec, normalx, normaly)
    if bit.band(game.KeyFlags, KEYFLAG_JUMPING) ~= 0 then
        game.KeyFlags = bit.band(game.KeyFlags, bit.bnot(bit.bor(KEYFLAG_JUMPING, bit.bor(KEYFLAG_JUMP, KEYFLAG_JUMP_ISSUED))))
    end

    local mul = vec[0 + INDEX_BASE] * normalx + vec[1 + INDEX_BASE] * normaly
    vec[0 + INDEX_BASE] = vec[0 + INDEX_BASE] - (mul * normalx)
    vec[1 + INDEX_BASE] = vec[1 + INDEX_BASE] - (mul * normaly)
    return mul
end

--[[

   SetAngle takes a surface normal, player angle and JustDoIt flag and
   decides how the player's interaction with that surface affects his
   angle.

   If JustDoIt is set then the function just sets the player to be at
   the angle of the normal, no questions asked.

   Otherwise the players angle is set if either:

      - the angle of the normal is close to vertical
      - the angle of the normal is close to the player angle

   Note that the arguments to atan2 are adjusted so that we're thinking
   in Allegro style angle measurements (i.e. 0 degrees = straight up,
   increases go clockwise) rather than the usual mathematics meaning
   (i.e. 0 degrees = right, increases go anticlockwise)

--]]
---@param normalx number
---@param normaly number
---@param a number
---@param JustDoIt boolean
---@return number
local function SetAngle(normalx, normaly, a, JustDoIt)
    local NewAng = atan2(normalx, -normaly)

    if JustDoIt or ((NewAng < (allegro5.ALLEGRO_PI * 0.25)) and (NewAng >= 0)) or
        ((NewAng > (-allegro5.ALLEGRO_PI * 0.25)) and (NewAng <= 0)) or
        fabs(NewAng - a) < (allegro5.ALLEGRO_PI * 0.25)
    then
        a = NewAng
    end

    return a
end

--[[

   DoFriction applies surface friction along an edge, taking the player's
   intended direction of travel into account

   First of all it breaks movement into 'ForwardSpeed' and 'UpSpeed', both
   relative to the edge - i.e. forward speed is motion parallel to the edge,
   upward speed is motion perpendicular

   Then the two are adjusted according to surface friction and player input,
   and finally put back together to reform the complete player velocity

--]]
---@param r number
---@param E Edge
---@param vec [number, number]
local function DoFriction(r, E, vec)
    --[[ calculate how quickly we're currently moving parallel and perpendicular to this edge --]]
    local ForwardSpeed = (vec[0 + INDEX_BASE] * E.b - vec[1 + INDEX_BASE] * E.a) / E.Material.Friction ---@type number
    local UpSpeed = vec[0 + INDEX_BASE] * E.a + vec[1 + INDEX_BASE] * E.b ---@type number

    --[[ apply adjustments based on user controls --]]
    if bit.band(game.KeyFlags, KEYFLAG_LEFT) ~= 0 then
        ForwardSpeed = ForwardSpeed + game.Pusher ---@type number
        game.KeyFlags = bit.bor(game.KeyFlags, KEYFLAG_FLIP)
    end
    if bit.band(game.KeyFlags, KEYFLAG_RIGHT) ~= 0 then
        ForwardSpeed = ForwardSpeed - game.Pusher ---@type number
        game.KeyFlags = bit.band(game.KeyFlags, bit.bnot(KEYFLAG_FLIP))
    end

    --[[ apply friction as necessary --]]
    local FricLevel = 0.05 * E.Material.Friction
    if ForwardSpeed > 0 then
        if ForwardSpeed < FricLevel then
            ForwardSpeed = 0
        else
            ForwardSpeed = ForwardSpeed - (FricLevel)
        end
    else
        if ForwardSpeed > -FricLevel then
            ForwardSpeed = 0
        else
            ForwardSpeed = ForwardSpeed + (FricLevel)
        end
    end

    --[[ add jump if requested --]]
    if bit.band(game.KeyFlags, bit.bor(KEYFLAG_JUMP, KEYFLAG_JUMP_ISSUED)) == KEYFLAG_JUMP then
        UpSpeed = UpSpeed + (5.0) ---@type number
        game.KeyFlags = bit.bor(game.KeyFlags, bit.bor(KEYFLAG_JUMP_ISSUED, KEYFLAG_JUMPING))
    end

    --[[ put velocity back together --]]
    vec[0 + INDEX_BASE] = UpSpeed * E.a + ForwardSpeed * E.Material.Friction * E.b
    vec[1 + INDEX_BASE] = UpSpeed * E.b - ForwardSpeed * E.Material.Friction * E.a
end

--[[

   RunPhysics is the centrepiece of the game simulation and is perhaps
   misnamed in that it runs physics and game logic generally.

   The basic structure is:

      apply gravity and air resistance;

      while(some simulation time remains)
      {
         find first thing the player hits during the simulation time

         run time forward until that hit occurs

         adjust player velocity according to whatever he has hit
      }

   Although some additional work needs to be done
--]]
-- #if 0 /* unused */
---@param lvl Level
---@param CollTree QuadTreeNode
---@param pos [number, number]
---@param vec [number, number]
---@param TimeToGo number
---@param PAnim Animation
---@return QuadTreeNode
local function DoContinuousPhysics(lvl, CollTree, pos, vec, TimeToGo, PAnim)
    local MoveVec = { 0, 0 } ---@type [number, number]
    local CollTime, NCollTime = 0, 0 ---@type number
    local End, ColPoint = { 0, 0 }, { 0, 0 } ---@type [number, number]
    local d1, d2 = 0, 0 ---@type number, number
    local E ---@type Edge
    local r = 0 ---@integer
    local Contact = false
    local EPtr, FirstEdge ---@type Container?

    --[[ save a small amount of time by finding the first edge here --]]
    CollTree = GetCollisionNode(lvl, pos, vec)
    EPtr = CollTree.Contents ---@type Container?
    while EPtr and EPtr.Type ~= EDGE do
        EPtr = EPtr.Next ---@type Container?
    end
    FirstEdge = EPtr

    --[[ do collisions and reactions --]]
    repeat
        Contact = false

        --[[ rounding error fixup --]]
        EPtr = FirstEdge
        while EPtr do
            --[[ simple line test --]]
            d1 =
                EPtr.Content.E.a * pos[0 + INDEX_BASE] +
                EPtr.Content.E.b * pos[1 + INDEX_BASE] + EPtr.Content.E.c

            if d1 >= (-0.5) and d1 <= 0.05 and
                pos[0 + INDEX_BASE] >= EPtr.Content.E.Bounder.TL.Pos[0 + INDEX_BASE]
                and pos[0 + INDEX_BASE] <= EPtr.Content.E.Bounder.BR.Pos[0 + INDEX_BASE]
                and pos[1 + INDEX_BASE] >= EPtr.Content.E.Bounder.TL.Pos[1 + INDEX_BASE]
                and pos[1 + INDEX_BASE] <= EPtr.Content.E.Bounder.BR.Pos[1 + INDEX_BASE]
            then
                pos[0 + INDEX_BASE] = pos[0 + INDEX_BASE] + (EPtr.Content.E.a * (0.05 - d1))
                pos[1 + INDEX_BASE] = pos[1 + INDEX_BASE] + (EPtr.Content.E.b * (0.05 - d1))
                Contact = true
            end

            EPtr = EPtr.Next ---@type Container?
        end

        MoveVec[0 + INDEX_BASE] = TimeToGo * vec[0 + INDEX_BASE]
        MoveVec[1 + INDEX_BASE] = TimeToGo * vec[1 + INDEX_BASE]

        CollTime = TimeToGo + 1.0 ---@type number
        End[0 + INDEX_BASE] = pos[0 + INDEX_BASE] + MoveVec[0 + INDEX_BASE]
        End[1 + INDEX_BASE] = pos[1 + INDEX_BASE] + MoveVec[1 + INDEX_BASE]
        local CollPtr ---@type Container|QuadTreeNode?

        --[[ search for collisions --]]

        --[[ test 1: do we hit the edge of this collision tree node? --]]
        if End[0 + INDEX_BASE] > CollTree.Bounder.BR.Pos[0 + INDEX_BASE] then
            NCollTime = (End[0 + INDEX_BASE] - CollTree.Bounder.BR.Pos[0 + INDEX_BASE]) / MoveVec[0 + INDEX_BASE]
            if NCollTime < CollTime then
                CollTime = NCollTime
                CollPtr = CollTree
            end
        end

        if End[0 + INDEX_BASE] < CollTree.Bounder.TL.Pos[0 + INDEX_BASE] then
            NCollTime = (End[0 + INDEX_BASE] - CollTree.Bounder.TL.Pos[0 + INDEX_BASE]) / MoveVec[0 + INDEX_BASE]
            if NCollTime < CollTime then
                CollTime = NCollTime
                CollPtr = CollTree
            end
        end

        if End[1 + INDEX_BASE] > CollTree.Bounder.BR.Pos[1 + INDEX_BASE] then
            NCollTime = (End[1 + INDEX_BASE] - CollTree.Bounder.BR.Pos[1 + INDEX_BASE]) / MoveVec[1 + INDEX_BASE]
            if NCollTime < CollTime then
                CollTime = NCollTime
                CollPtr = CollTree
            end
        end

        if End[1 + INDEX_BASE] < CollTree.Bounder.TL.Pos[1 + INDEX_BASE] then
            NCollTime = (End[1 + INDEX_BASE] - CollTree.Bounder.TL.Pos[1 + INDEX_BASE]) / MoveVec[1 + INDEX_BASE]
            if NCollTime < CollTime then
                CollTime = NCollTime
                CollPtr = CollTree
            end
        end

        --[[ test 2: do we hit any of the edges contained in the tree? --]]
        EPtr = FirstEdge
        while EPtr do
            --[[ simple line test --]]
            ---@type number
            d1 =
                EPtr.Content.E.a * pos[0 + INDEX_BASE] +
                EPtr.Content.E.b * pos[1 + INDEX_BASE] + EPtr.Content.E.c
            ---@type number
            d2 =
                EPtr.Content.E.a * End[0 + INDEX_BASE] +
                EPtr.Content.E.b * End[1 + INDEX_BASE] + EPtr.Content.E.c
            if (d1 >= (-0.05)) and (d2 < 0) then
                NCollTime = d1 / (d1 - d2) ---@type number

                ColPoint[0 + INDEX_BASE] = pos[0 + INDEX_BASE] + NCollTime * MoveVec[0 + INDEX_BASE]
                ColPoint[1 + INDEX_BASE] = pos[1 + INDEX_BASE] + NCollTime * MoveVec[1 + INDEX_BASE]
                if ColPoint[0 + INDEX_BASE] >= EPtr.Content.E.Bounder.TL.Pos[0 + INDEX_BASE]
                    and ColPoint[0 + INDEX_BASE] <= EPtr.Content.E.Bounder.BR.Pos[0 + INDEX_BASE]
                    and ColPoint[1 + INDEX_BASE] >= EPtr.Content.E.Bounder.TL.Pos[1 + INDEX_BASE]
                    and ColPoint[1 + INDEX_BASE] <= EPtr.Content.E.Bounder.BR.Pos[1 + INDEX_BASE]
                then
                    CollTime = NCollTime
                    CollPtr = EPtr
                end
            end

            --[[ move to next edge --]]
            EPtr = EPtr.Next
        end

        --[[ advance - apply motion and resulting friction here! --]]
        pos[0 + INDEX_BASE] = pos[0 + INDEX_BASE] + (MoveVec[0 + INDEX_BASE] * CollTime)
        pos[1 + INDEX_BASE] = pos[1 + INDEX_BASE] + (MoveVec[1 + INDEX_BASE] * CollTime)
        if not Contact then
            AdvanceAnimation(PAnim, 0, false)
        end

        --[[ fix up --]]
        if CollPtr then
            if CollPtr == CollTree then
                CollTree = GetCollisionNode(lvl, pos, vec)

                --[[ find new first edge --]]
                EPtr = CollTree.Contents
                while EPtr and EPtr.Type ~= EDGE do
                    EPtr = EPtr.Next
                end
                FirstEdge = EPtr
            elseif CollPtr.Content.E then
                --[[ edge collision --]]
                E = CollPtr.Content.E ---@type Edge
                r = FixUp(vec, E.a, E.b)

                pos[2 + INDEX_BASE] = SetAngle(E.a, E.b, pos[2 + INDEX_BASE],
                    (fabs(vec[0 + INDEX_BASE] * E.b - vec[1 + INDEX_BASE] * E.a) > 0.5))
                AdvanceAnimation(PAnim,
                    (vec[0 + INDEX_BASE] * E.b -
                        vec[1 + INDEX_BASE] * E.a) *
                    ((function() if bit.band(game.KeyFlags, KEYFLAG_FLIP) ~= 0 then return 1.0 else return -1.0 end end)()),
                    true)

                --[[ apply friction --]]
                DoFriction(r, E, vec)
            end
        elseif not Contact then
            --[[ check if currently in contact with any surface. If not then do empty space movement --]]
            if bit.band(game.KeyFlags, KEYFLAG_LEFT) ~= 0 then
                vec[0 + INDEX_BASE] = vec[0 + INDEX_BASE] - (0.05)
                game.KeyFlags = bit.bor(game.KeyFlags, KEYFLAG_FLIP)
            end
            if bit.band(game.KeyFlags, KEYFLAG_RIGHT) ~= 0 then
                vec[0 + INDEX_BASE] = vec[0 + INDEX_BASE] + (0.05)
                game.KeyFlags = bit.band(game.KeyFlags, bit.bnot(KEYFLAG_FLIP))
            end
            if pos[2 + INDEX_BASE] > 0 then
                pos[2 + INDEX_BASE] = pos[2 + INDEX_BASE] - (TimeToGo * CollTime * 0.03)
                if pos[2 + INDEX_BASE] < 0 then
                    pos[2 + INDEX_BASE] = 0
                end
            end
            if pos[2 + INDEX_BASE] < 0 then
                pos[2 + INDEX_BASE] = pos[2 + INDEX_BASE] + (TimeToGo * CollTime * 0.03)
                if pos[2 + INDEX_BASE] > 0 then
                    pos[2 + INDEX_BASE] = 0
                end
            end
        end

        --[[ reduce time & continue --]]
        TimeToGo = TimeToGo - (TimeToGo * CollTime)
    until not (TimeToGo > 0.01)

    return CollTree
end
-- #endif

--[[static __auto__ TIME_STEP =         0.6f;
struct QuadTreeNode *RunPhysics(struct Level *lvl, double *pos, double *vec, double TimeToGo, struct Animation *PAnim)
{
   struct QuadTreeNode *CollTree = GetCollisionNode(lvl, pos, vec);
   static double TimeAccumulator = 0;
   double Step;

   TimeAccumulator += TimeToGo;

   Step = fmod(TimeAccumulator, TIME_STEP);
   if(Step >= 0.01f) {
      TimeAccumulator -= Step;
      CollTree = DoContinuousPhysics(lvl, CollTree, pos, vec, Step, PAnim);
   }

   while(TimeAccumulator > 0) {
      ve + INDEX_BASEc[1] += 0.1f;

      ve + INDEX_BASEc[0] *= 0.997f;
      ve + INDEX_BASEc[1] *= 0.997f;

      CollTree = DoContinuousPhysics(lvl, CollTree, pos, vec, TimeToGo, PAnim);
      TimeAccumulator -= TIME_STEP;
   }

   return CollTree;
}--]]
---@param lvl Level
---@param pos [number, number]
---@param vec [number, number]
---@param TimeToGo number
---@param PAnim Animation
---@return QuadTreeNode
local function RunPhysics(lvl, pos, vec, TimeToGo, PAnim)
    local MoveVec = { 0, 0 } ---@type [number, number]
    local CollTree = GetCollisionNode(lvl, pos, vec)
    local CollTime, NCollTime = 0, 0 ---@type number
    local End, ColPoint = { 0, 0 }, { 0, 0 } ---@type [number, number]
    local d1, d2 = 0, 0 ---@type number, number
    local r = 0 ---@type number
    local Contact = false
    local EPtr, FirstEdge ---@type Container?, Container?

    --[[ Step 1: apply gravity --]]
    vec[1 + INDEX_BASE] = vec[1 + INDEX_BASE] + (0.1)

    --[[ Step 2: apply atmoshperic resistance --]]
    vec[0 + INDEX_BASE] = vec[0 + INDEX_BASE] * (0.997)
    vec[1 + INDEX_BASE] = vec[1 + INDEX_BASE] * (0.997)

    EPtr = CollTree.Contents
    while EPtr and EPtr.Type ~= EDGE do
        EPtr = EPtr.Next ---@type Container?
    end
    FirstEdge = EPtr

    --[[ Step 2: do collisions and reactions --]]
    repeat
        Contact = false

        --[[ rounding error fixup --]]
        EPtr = FirstEdge
        while EPtr do
            --[[ simple line test --]]
            d1 =
                EPtr.Content.E.a * pos[0 + INDEX_BASE] +
                EPtr.Content.E.b * pos[1 + INDEX_BASE] + EPtr.Content.E.c

            if d1 >= (-0.5) and d1 <= 0.05 and
                pos[0 + INDEX_BASE] >= EPtr.Content.E.Bounder.TL.Pos[0 + INDEX_BASE]
                and pos[0 + INDEX_BASE] <= EPtr.Content.E.Bounder.BR.Pos[0 + INDEX_BASE]
                and pos[1 + INDEX_BASE] >= EPtr.Content.E.Bounder.TL.Pos[1 + INDEX_BASE]
                and pos[1 + INDEX_BASE] <= EPtr.Content.E.Bounder.BR.Pos[1 + INDEX_BASE]
            then
                pos[0 + INDEX_BASE] = pos[0 + INDEX_BASE] + (EPtr.Content.E.a * (0.05 - d1))
                pos[1 + INDEX_BASE] = pos[1 + INDEX_BASE] + (EPtr.Content.E.b * (0.05 - d1))
                Contact = true
            end

            EPtr = EPtr.Next---@type Container?
        end

        MoveVec[0 + INDEX_BASE] = TimeToGo * vec[0 + INDEX_BASE]
        MoveVec[1 + INDEX_BASE] = TimeToGo * vec[1 + INDEX_BASE]

        CollTime = 1.0
        End[0 + INDEX_BASE] = pos[0 + INDEX_BASE] + MoveVec[0 + INDEX_BASE]
        End[1 + INDEX_BASE] = pos[1 + INDEX_BASE] + MoveVec[1 + INDEX_BASE]
        local CollPtr = nil ---@type QuadTreeNode|Container?

        --[[ search for collisions here --]]

        --[[ test 1: do we hit the edge of this collision tree node? --]]
        if End[0 + INDEX_BASE] > CollTree.Bounder.BR.Pos[0 + INDEX_BASE] then
            NCollTime = (End[0 + INDEX_BASE] - CollTree.Bounder.BR.Pos[0 + INDEX_BASE]) / MoveVec[0 + INDEX_BASE]
            if NCollTime < CollTime then
                CollTime = NCollTime
                CollPtr = CollTree
            end
        end

        if End[0 + INDEX_BASE] < CollTree.Bounder.TL.Pos[0 + INDEX_BASE] then
            NCollTime = (End[0 + INDEX_BASE] - CollTree.Bounder.TL.Pos[0 + INDEX_BASE]) / MoveVec[0 + INDEX_BASE]
            if NCollTime < CollTime then
                CollTime = NCollTime
                CollPtr = CollTree
            end
        end

        if End[1 + INDEX_BASE] > CollTree.Bounder.BR.Pos[1 + INDEX_BASE] then
            NCollTime = (End[1 + INDEX_BASE] - CollTree.Bounder.BR.Pos[1 + INDEX_BASE]) / MoveVec[1 + INDEX_BASE]
            if NCollTime < CollTime then
                CollTime = NCollTime
                CollPtr = CollTree
            end
        end

        if End[1 + INDEX_BASE] < CollTree.Bounder.TL.Pos[1 + INDEX_BASE] then
            NCollTime = (End[1 + INDEX_BASE] - CollTree.Bounder.TL.Pos[1 + INDEX_BASE]) / MoveVec[1 + INDEX_BASE]
            if NCollTime < CollTime then
                CollTime = NCollTime
                CollPtr = CollTree
            end
        end

        --[[ test 3: do we hit any of the edges contained in the tree? --]]
        EPtr = FirstEdge
        while EPtr do
            --[[ simple line test --]]
            ---@type number
            d1 =
                EPtr.Content.E.a * pos[0 + INDEX_BASE] +
                EPtr.Content.E.b * pos[1 + INDEX_BASE] + EPtr.Content.E.c
            ---@type number
            d2 =
                EPtr.Content.E.a * End[0 + INDEX_BASE] +
                EPtr.Content.E.b * End[1 + INDEX_BASE] + EPtr.Content.E.c
            if (d1 >= (-0.05)) and (d2 < 0) then
                NCollTime = d1 / (d1 - d2)

                ColPoint[0 + INDEX_BASE] = pos[0 + INDEX_BASE] + NCollTime * MoveVec[0 + INDEX_BASE]
                ColPoint[1 + INDEX_BASE] = pos[1 + INDEX_BASE] + NCollTime * MoveVec[1 + INDEX_BASE]
                if ColPoint[0 + INDEX_BASE] >= EPtr.Content.E.Bounder.TL.Pos[0 + INDEX_BASE]
                    and ColPoint[0 + INDEX_BASE] <= EPtr.Content.E.Bounder.BR.Pos[0 + INDEX_BASE]
                    and ColPoint[1 + INDEX_BASE] >= EPtr.Content.E.Bounder.TL.Pos[1 + INDEX_BASE]
                    and ColPoint[1 + INDEX_BASE] <= EPtr.Content.E.Bounder.BR.Pos[1 + INDEX_BASE]
                then
                    CollTime = NCollTime
                    CollPtr = EPtr
                end
            end

            --[[ move to next edge --]]
            EPtr = EPtr.Next
        end

        --[[ advance - apply motion and resulting friction here! --]]
        pos[0 + INDEX_BASE] = pos[0 + INDEX_BASE] + (MoveVec[0 + INDEX_BASE] * CollTime)
        pos[1 + INDEX_BASE] = pos[1 + INDEX_BASE] + (MoveVec[1 + INDEX_BASE] * CollTime)
        if not Contact then
            AdvanceAnimation(PAnim, 0, false)
        end

        --[[ fix up --]]
        if CollPtr then
            if CollPtr == CollTree then
                CollTree = GetCollisionNode(lvl, pos, vec)
                EPtr = CollTree.Contents
                while EPtr and EPtr.Type ~= EDGE do
                    EPtr = EPtr.Next
                end
                FirstEdge = EPtr
            elseif CollPtr.Content.E then
                --[[ edge collision --]]
                local E = CollPtr.Content.E ---@type Edge
                r = FixUp(vec, E.a, E.b)

                pos[2 + INDEX_BASE] = SetAngle(E.a, E.b, pos[2 + INDEX_BASE],
                    (fabs(vec[0 + INDEX_BASE] * E.b - vec[1 + INDEX_BASE] * E.a) > 0.5))
                AdvanceAnimation(PAnim,
                    (vec[0 + INDEX_BASE] * E.b -
                        vec[1 + INDEX_BASE] * E.a) *
                    ((function() if bit.band(game.KeyFlags, KEYFLAG_FLIP) ~= 0 then return 1.0 else return -1.0 end end)()),
                    true)

                --[[ apply friction --]]
                DoFriction(r, E, vec)
            end
        elseif not Contact then
            --[[ check if currently in contact with any surface. If not then do empty space movement --]]
            if bit.band(game.KeyFlags, KEYFLAG_LEFT) ~= 0 then
                vec[0 + INDEX_BASE] = vec[0 + INDEX_BASE] - (0.05)
                game.KeyFlags = bit.bor(game.KeyFlags, KEYFLAG_FLIP)
            end
            if bit.band(game.KeyFlags, KEYFLAG_RIGHT) ~= 0 then
                vec[0 + INDEX_BASE] = vec[0 + INDEX_BASE] + (0.05)
                game.KeyFlags = bit.band(game.KeyFlags, bit.bnot(KEYFLAG_FLIP))
            end
            if pos[2 + INDEX_BASE] > 0 then
                pos[2 + INDEX_BASE] = pos[2 + INDEX_BASE] - (TimeToGo * CollTime * 0.03)
                if pos[2 + INDEX_BASE] < 0 then
                    pos[2 + INDEX_BASE] = 0
                end
            end
            if pos[2 + INDEX_BASE] < 0 then
                pos[2 + INDEX_BASE] = pos[2 + INDEX_BASE] + (TimeToGo * CollTime * 0.03)
                if pos[2 + INDEX_BASE] > 0 then
                    pos[2 + INDEX_BASE] = 0
                end
            end
        end

        --[[ reduce time & continue --]]
        TimeToGo = TimeToGo - (TimeToGo * CollTime) ---@type number
    until not (TimeToGo > 0.01)

    return CollTree
end
exports.RunPhysics = RunPhysics

return exports
