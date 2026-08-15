---@class game
---@field KeyFlags integer
---@field Pusher number
local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/game.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global

local anim = require("anim")
local common = require("examples.common")
local defines = require("defines")
local demodata = require("demodata")
local _global = require("global")
local keyboard = require("keyboard")
local level = require("level")
local level_state = require("level_state")
local menus = require("menus")
local music = require("music")
local physics ---@module 'physics'
local quadtree = require("quadtree")

local RunPhysics ---@type fun(lvl: Level, pos: [number, number], vec: [number, number], TimeToGo: number, PAnim: Animation) : QuadTreeNode

exports.init = function()
    physics = require("physics")

    RunPhysics = physics.RunPhysics
end

local FreePlayerAnimation = anim.FreePlayerAnimation
local GetCurrentBitmap = anim.GetCurrentBitmap
local PauseAnimation = anim.PauseAnimation
local SeedPlayerAnimation = anim.SeedPlayerAnimation
local UnpauseAnimation = anim.UnpauseAnimation

local new_array = common.new_array
local new_table = common.new_table
local rand = common.rand
local RAND_MAX = common.RAND_MAX

local DEMO_STATE_CONTINUE_GAME = defines.DEMO_STATE_CONTINUE_GAME
local DEMO_STATE_MAIN_MENU = defines.DEMO_STATE_MAIN_MENU
local DEMO_STATE_NEW_GAME = defines.DEMO_STATE_NEW_GAME
local DEMO_STATE_SUCCESS = defines.DEMO_STATE_SUCCESS

local DEMO_MIDI_INGAME = demodata.DEMO_MIDI_INGAME

local controller = _global.controller
local demo_textprintf = _global.demo_textprintf

local key_pressed = keyboard.key_pressed

local DrawLevelBackground = level.DrawLevelBackground
local DrawLevelForeground = level.DrawLevelForeground
local FreeLevel = level.FreeLevel
local GetLevelError = level.GetLevelError
local LoadLevel = level.LoadLevel
local ObtainBitmap = level.ObtainBitmap
local ObtainSample = level.ObtainSample

local BorrowState = level_state.BorrowState
local FreeState = level_state.FreeState
local ReturnState = level_state.ReturnState
local SetDoorOpen = level_state.SetDoorOpen
local SetInitialState = level_state.SetInitialState

local enable_continue_game = menus.enable_continue_game

local play_music = music.play_music
local play_sound = music.play_sound

local OBJECT = quadtree.OBJECT
local OBJFLAGS_DOOR = quadtree.OBJFLAGS_DOOR
local OBJFLAGS_VISIBLE = quadtree.OBJFLAGS_VISIBLE

local INDEX_BASE = 1 -- lua is 1-based indexed

local atan2 = math.atan2 or math.atan ---@diagnostic disable-line: deprecated
local ceil = math.ceil
local cos = math.cos
local sin = math.sin
local tan = math.tan

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ global game state defines and variables --]]
local KEYFLAG_LEFT = 0x01
local KEYFLAG_RIGHT = 0x02
local KEYFLAG_JUMP = 0x04
local KEYFLAG_JUMP_ISSUED = 0x08
local KEYFLAG_JUMPING = 0x10
local KEYFLAG_FLIP = 0x20

exports.KEYFLAG_LEFT = KEYFLAG_LEFT
exports.KEYFLAG_RIGHT = KEYFLAG_RIGHT
exports.KEYFLAG_JUMP = KEYFLAG_JUMP
exports.KEYFLAG_JUMP_ISSUED = KEYFLAG_JUMP_ISSUED
exports.KEYFLAG_JUMPING = KEYFLAG_JUMPING
exports.KEYFLAG_FLIP = KEYFLAG_FLIP

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/game.c
--]]

--[[

   All variables relevant to player position and level / level status. Only
   thing of note is that is a 3 element array - it contains
   player position (in elements 0 and 1) and rotation (in element 2)

--]]
local KeyFlags = 0 ---@type integer
local RequiredObjectsLeft, TotalObjectsLeft = 0, 0 ---@type integer
local PlayerPos = {0, 0, 0} ---@type [number, number, number]
local PlayerVec = {0, 0} ---@type [number, number]
local ScrollPos = {0, 0} ---@type [number, number]
local PlayerAnim = nil ---@type Animation?
local Lvl = nil ---@type Level?
local LvlState = nil ---@type LevelState?
local LeftWindow, RightWindow = -120, 120 ---@type integer, integer
local Pusher = 0 ---@type number
local cloud_color = allegro5.ALLEGRO_COLOR()

local PLAYER_STRENGTH = 0.14

--[[

   ID things, for GAMESTATE purposes. Note that two menu entries head this way -
   "new game" and "continue game", so we have to IDs

--]]
local _newid = DEMO_STATE_NEW_GAME ---@type integer

---@return integer
local function newid()
    return _newid
end

local _continueid = DEMO_STATE_CONTINUE_GAME ---@type integer

---@return integer
local function continueid()
    return _continueid
end

local CurrentID = 0 ---@type integer

--[[ background stuff --]]
local water ---@type ALLEGRO_BITMAP?
local WaterVoice, WaterVoice2 = nil, nil ---@type ALLEGRO_SAMPLE_INSTANCE?
local WaveNoise = nil ---@type ALLEGRO_SAMPLE?

local cloud = nil ---@type ALLEGRO_BITMAP?
local TanTable = nil ---@type integer[]?
local CalibRes = 0 ---@type integer

local TexX = 0 ---@type number
local WaveY = 0 ---@type number

local Clouds = new_table(function() return { x = 0, y = 0 } end, 8) ---@type { x: number, y: number }[]
local CloudX = 0 ---@type number

---@param data_path string
---@return string?
local function load_game_resources(data_path)
    io.write("load_game_resources\n")
    local path = allegro5.al_create_path_for_directory(data_path)
    allegro5.al_set_path_filename(path, "level.txt")
    Lvl = LoadLevel(allegro5.al_path_cstr(path, '/'), 15)
    allegro5.al_destroy_path(path)

    if not Lvl then
        return GetLevelError()
    end

    ReturnState(Lvl, LvlState)

    PlayerAnim = SeedPlayerAnimation()
    cloud = ObtainBitmap("cloud")
    water = ObtainBitmap("water")

    local c = bit.lshift(480, 2) ---@type integer
    TanTable = {}
    while c ~= 0 do
        c = c - 1
        TanTable[c + INDEX_BASE] =
            allegro5.al_ftofix(tan((3.141592654 / 2.0 -
                    atan2(0.75 *
                        ((c * 2) / bit.lshift(480, 2) - 1), 1)
                )))
    end

    WaveNoise = ObtainSample("wave")

    cloud_color = allegro5.al_get_pixel(cloud, 0, 0)

    return nil
end
exports.load_game_resources = load_game_resources

local function unload_game_resources()
    io.write("unload_game_resources\n")
    FreePlayerAnimation(PlayerAnim)
    PlayerAnim = nil

    FreeState(LvlState)
    LvlState = BorrowState(Lvl)
    FreeLevel(Lvl)
    Lvl = nil

    if TanTable then
        TanTable = nil
    end
end
exports.unload_game_resources = unload_game_resources

local function DeInit()
    if WaterVoice then
        allegro5.al_stop_sample_instance(WaterVoice)
        allegro5.al_destroy_sample_instance(WaterVoice)
        WaterVoice = nil
    end
    if WaterVoice2 then
        allegro5.al_stop_sample_instance(WaterVoice2)
        allegro5.al_destroy_sample_instance(WaterVoice2)
        WaterVoice2 = nil
    end
    PauseAnimation(PlayerAnim)
end

local function GenericInit()
    CloudX = 0
    Clouds[0 + INDEX_BASE].y = 0; Clouds[0 + INDEX_BASE].x = Clouds[0 + INDEX_BASE].y
    for c = 1, 8 - INDEX_BASE do
        Clouds[c + INDEX_BASE].x =
            Clouds[c - 1 + INDEX_BASE].x + allegro5.al_get_bitmap_width(cloud) + 8 +
            rand() * (_global.screen_width * 480 / _global.screen_height / 8) / RAND_MAX
        Clouds[c + INDEX_BASE].y = rand() * 0.5 * 480 / RAND_MAX
    end

    WaterVoice = allegro5.al_create_sample_instance(WaveNoise)
    allegro5.al_set_sample_instance_playmode(WaterVoice, allegro5.ALLEGRO_PLAYMODE_BIDIR)
    allegro5.al_set_sample_instance_gain(WaterVoice, 0.5)
    allegro5.al_attach_sample_instance_to_mixer(WaterVoice, allegro5.al_get_default_mixer())
    allegro5.al_play_sample_instance(WaterVoice)

    WaterVoice2 = allegro5.al_create_sample_instance(WaveNoise)
    allegro5.al_set_sample_instance_playmode(WaterVoice2,
        allegro5.ALLEGRO_PLAYMODE_BIDIR)
    allegro5.al_set_sample_instance_gain(WaterVoice2, 0.25)
    allegro5.al_attach_sample_instance_to_mixer(WaterVoice2, allegro5.al_get_default_mixer())
    allegro5.al_play_sample_instance(WaterVoice2)

    play_music(DEMO_MIDI_INGAME, true)
    UnpauseAnimation(PlayerAnim)
end

local function ContinueInit()
    GenericInit()
    CurrentID = continueid()
end

local function GameInit()
    if not Lvl then
        return
    end

    KeyFlags = 0
    enable_continue_game()

    SetInitialState(Lvl)
    PlayerPos[0 + INDEX_BASE] = Lvl.PlayerStartPos[0 + INDEX_BASE]; ScrollPos[0 + INDEX_BASE] = PlayerPos[0 + INDEX_BASE]
    PlayerPos[1 + INDEX_BASE] = Lvl.PlayerStartPos[1 + INDEX_BASE]; ScrollPos[1 + INDEX_BASE] = PlayerPos[1 + INDEX_BASE]
    PlayerVec[1 + INDEX_BASE] = 0; PlayerVec[0 + INDEX_BASE] = PlayerVec[1 + INDEX_BASE]
    RequiredObjectsLeft = Lvl.ObjectsRequired
    TotalObjectsLeft = Lvl.TotalObjects

    GenericInit()
    CurrentID = newid()
end

local function DrawClouds()
    local c = 8 ---@type integer
    local x1, y1, x2, y2, x = 0, 0, 0, 0, 0 ---@type number

    while c ~= 0 do
        c = c - 1
        x = Clouds[c + INDEX_BASE].x + CloudX

        x1 = (x - sin(x) * 1.4)
        x2 = (x + allegro5.al_get_bitmap_width(cloud) + sin(x) * 1.4)
        y1 = (Clouds[c + INDEX_BASE].y - cos(x) * 1.4)
        y2 = (Clouds[c + INDEX_BASE].y + allegro5.al_get_bitmap_height(cloud) + cos(x) * 1.4)

        if x2 < 0 then
            Clouds[c + INDEX_BASE].x =
                Clouds[bit.band((c - 1), 7) + INDEX_BASE].x + allegro5.al_get_bitmap_width(cloud) + 8 +
                (rand() * 32.0 / RAND_MAX)
            Clouds[c + INDEX_BASE].y = rand() * 0.5 * _global.screen_height / RAND_MAX
        else
            allegro5.al_draw_scaled_bitmap(cloud, 0, 0, allegro5.al_get_bitmap_width(cloud),
                allegro5.al_get_bitmap_height(cloud),
                x1, y1, x2 - x1, y2 - y1, 0)
        end
    end
end

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

local function GameDraw()
    local depth = 0 ---@type number
    local Points, Points_ptr = new_array("ALLEGRO_VERTEX", 4)
    local transform = allegro5.ALLEGRO_TRANSFORM()

    allegro5.al_identity_transform(transform)
    allegro5.al_scale_transform(transform, _global.screen_height / 480.0, _global.screen_height / 480.0)
    allegro5.al_use_transform(transform)

    local w = _global.screen_width * 480.0 / _global.screen_height

    --[[ draw background --]]
    if TanTable then
        local c = 480 * 4 - 1
        local y2, lowy, y1, u = 0, 480, 0, 0
        local index = 0

        while c > 480 * 2 + 15 do
            depth = allegro5.al_fixtof(allegro5.al_fixmul(TanTable[c + INDEX_BASE],
                math.floor((ScrollPos[1 + INDEX_BASE] - 240) * 4096.0)))

            if depth > -261 and depth < -5.0 then
                local d = bit.band((math.floor(depth * 65536)), (256 * 65536 - 1))
                y1 = lowy
                index = (d / 65536.0 - 1.0) * allegro5.ALLEGRO_PI * 2 * 8 / 128.0

                y2 = c / 4.0 - 125.0 * sin(index + WaveY) / depth

                if y2 < lowy then
                    lowy = ceil(y2)

                    u = 64 + ScrollPos[0 + INDEX_BASE] / 8 + TexX
                    set_v(Points[0], 0, y2, u + depth * 4, depth + 5)
                    set_v(Points[1], w, y2, u - depth * 4, depth + 5)
                    set_v(Points[2], w, y1, u - depth * 4, depth + 5)
                    set_v(Points[3], 0, y1, u + depth * 4, depth + 5)

                    allegro5.al_draw_prim(Points_ptr, nil, water, 0, 4, allegro5.ALLEGRO_PRIM_TRIANGLE_FAN)
                end
            end
            c = c - 1
        end

        allegro5.al_set_clipping_rectangle(0, 0, _global.screen_width, math.floor(lowy * _global.screen_height / 480) + 1)
        allegro5.al_clear_to_color(cloud_color)
        DrawClouds()
        allegro5.al_set_clipping_rectangle(0, 0, _global.screen_width, _global.screen_height)
    end

    --[[ draw interactable parts of level --]]
    DrawLevelBackground(Lvl, ScrollPos)

    -- -- #ifdef DEBUG_EDGES
    --    solid_mode()
    --    local E = Lvl.AllEdges

    --    while  E  do
    --       line(buffer,
    --            E.EndPoints[0 + INDEX_BASE].Normal[0 + INDEX_BASE] - x + (bit.rshift(global.screen_width , 1)),
    --            E.EndPoints[0 + INDEX_BASE].Normal[1 + INDEX_BASE] - y + (bit.rshift(global.screen_height , 1)),
    --            E.EndPoints[1 + INDEX_BASE].Normal[0 + INDEX_BASE] - x + (bit.rshift(global.screen_width , 1)),
    --            E.EndPoints[1 + INDEX_BASE].Normal[1 + INDEX_BASE] - y + (bit.rshift(global.screen_height , 1)), allegro5.al_map_rgb(0, 0,
    --                                                                      0))
    --       E = E.Next
    --    end
    -- -- #endif

    -- -- #ifdef DEBUG_OBJECTS
    --    local O = Lvl.AllObjects

    --    while  O  do
    --       rect(buffer,
    --            O.Bounder.TL.Pos[0 + INDEX_BASE] - x + (bit.rshift(global.screen_width , 1)),
    --            O.Bounder.TL.Pos[1 + INDEX_BASE] - y + (bit.rshift(global.screen_height , 1)),
    --            O.Bounder.BR.Pos[0 + INDEX_BASE] - x + (bit.rshift(global.screen_width , 1)),
    --            O.Bounder.BR.Pos[1 + INDEX_BASE] - y + (bit.rshift(global.screen_height , 1)), allegro5.al_map_rgb(0, 0, 0))
    --       circle(buffer, O.Pos[0] - x + (bit.rshift(global.screen_width , 1)),
    --              O.Pos[1 + INDEX_BASE] - y + (bit.rshift(global.screen_height , 1)), O.ObjType.Radius, allegro5.al_map_rgb(0,
    --                                                                           0,
    --                                                                           0))
    --       O = O.Next
    --    end
    -- -- #endif

    --[[ add player sprite --]]
    local ch = GetCurrentBitmap(PlayerAnim)
    local chw = allegro5.al_get_bitmap_width(ch) ---@type integer
    local chh = allegro5.al_get_bitmap_height(ch) ---@type integer

    allegro5.al_draw_scaled_rotated_bitmap(ch, chw / 2.0, chh / 2.0,
        (PlayerPos[0 + INDEX_BASE] - ScrollPos[0 + INDEX_BASE]) + w / 2,
        (PlayerPos[1 + INDEX_BASE] - ScrollPos[1 + INDEX_BASE]) + 480.0 / 2,
        1, 1, PlayerPos[2 + INDEX_BASE],
        (function() if bit.band(KeyFlags, KEYFLAG_FLIP) ~= 0 then return allegro5.ALLEGRO_FLIP_HORIZONTAL else return 0 end end)())

    DrawLevelForeground(Lvl)

    allegro5.al_identity_transform(transform)
    allegro5.al_use_transform(transform)

    --[[ add status --]]
    demo_textprintf(_global.demo_font,
        _global.screen_width - allegro5.al_get_text_width(_global.demo_font,
            "Items Required: 1000"), 8,
        allegro5.al_map_rgb(255, 255, 255), "Items Required: %d",
        RequiredObjectsLeft)
    demo_textprintf(_global.demo_font,
        _global.screen_width - allegro5.al_get_text_width(_global.demo_font,
            "Items Remaining: 1000"),
        8 + allegro5.al_get_font_line_height(_global.demo_font), allegro5.al_map_rgb(255, 255, 255),
        "Items Remaining: %d", TotalObjectsLeft)
end

local function GameUpdate()
    if RequiredObjectsLeft < 0 then
        return DEMO_STATE_SUCCESS
    end

    TexX = TexX + (0.3)
    WaveY = WaveY - (0.02)
    CloudX = CloudX - (0.125)

    --[[ scrolling --]]
    if (PlayerPos[0 + INDEX_BASE] - ScrollPos[0 + INDEX_BASE]) < LeftWindow then
        ScrollPos[0 + INDEX_BASE] = PlayerPos[0 + INDEX_BASE] - LeftWindow
    end
    if (PlayerPos[0 + INDEX_BASE] - ScrollPos[0 + INDEX_BASE]) > RightWindow then
        ScrollPos[0 + INDEX_BASE] = PlayerPos[0 + INDEX_BASE] - RightWindow
    end
    if (PlayerPos[1 + INDEX_BASE] - ScrollPos[1 + INDEX_BASE]) < -80 then
        ScrollPos[1 + INDEX_BASE] = PlayerPos[1 + INDEX_BASE] + 80
    end
    if (PlayerPos[1 + INDEX_BASE] - ScrollPos[1 + INDEX_BASE]) > 80 then
        ScrollPos[1 + INDEX_BASE] = PlayerPos[1 + INDEX_BASE] - 80
    end

    if bit.bxor(bit.band(KeyFlags, KEYFLAG_FLIP), (function()
            if ((PlayerPos[2 + INDEX_BASE] < allegro5.ALLEGRO_PI * 0.5)
                    and (PlayerPos[2 + INDEX_BASE] >
                        -allegro5.ALLEGRO_PI * 0.5)) then
                return 0
            else
                return KEYFLAG_FLIP
            end
        end)()) ~= 0
    then
        if LeftWindow < 0 then
            LeftWindow = LeftWindow + 1 ---@type integer
        end
        if RightWindow < 120 then
            RightWindow = RightWindow + 1 ---@type integer
        end
    else
        if LeftWindow > -120 then
            LeftWindow = LeftWindow - 1
        end
        if RightWindow > 0 then
            RightWindow = RightWindow - 1
        end
    end

    --[[ update controls --]]
    controller[_global.controller_id + INDEX_BASE].poll(controller[_global.controller_id + INDEX_BASE])
    if controller[_global.controller_id + INDEX_BASE].button[0 + INDEX_BASE] then
        if bit.band(KeyFlags, KEYFLAG_LEFT) ~= 0 then
            Pusher = Pusher + (0.005)
            if Pusher >= PLAYER_STRENGTH then
                Pusher = PLAYER_STRENGTH
            end
        else
            KeyFlags = bit.bor(KeyFlags, KEYFLAG_LEFT)
            Pusher = 0
        end
    else
        KeyFlags = bit.band(KeyFlags, bit.bnot(KEYFLAG_LEFT))
    end

    if controller[_global.controller_id + INDEX_BASE].button[1 + INDEX_BASE] then
        if bit.band(KeyFlags, KEYFLAG_RIGHT) ~= 0 then
            Pusher = Pusher + (0.005)
            if Pusher >= PLAYER_STRENGTH then
                Pusher = PLAYER_STRENGTH
            end
        else
            KeyFlags = bit.bor(KeyFlags, KEYFLAG_RIGHT)
            Pusher = 0
        end
    else
        KeyFlags = bit.band(KeyFlags, bit.bnot(KEYFLAG_RIGHT))
    end

    if controller[_global.controller_id + INDEX_BASE].button[2 + INDEX_BASE] then
        KeyFlags = bit.bor(KeyFlags, KEYFLAG_JUMP)
    else
        if bit.band(KeyFlags, KEYFLAG_JUMPING) ~= 0 and PlayerVec[1 + INDEX_BASE] < -2.0 then
            PlayerVec[1 + INDEX_BASE] = -2.0
        end
        KeyFlags = bit.band(KeyFlags, bit.bnot(bit.bor(KEYFLAG_JUMP, KEYFLAG_JUMP_ISSUED)))
    end

    --[[ run physics --]]
    local CollTree = RunPhysics(Lvl, PlayerPos, PlayerVec, 0.6, PlayerAnim)
    local EPtr = CollTree.Contents ---@type Container?
    --[[ check whether any objects are collected --]]
    while EPtr and EPtr.Type == OBJECT do
        if bit.band(EPtr.Content.O.Flags, OBJFLAGS_VISIBLE) ~= 0 then
            local XDiff = PlayerPos[0 + INDEX_BASE] - EPtr.Content.O.Pos[0 + INDEX_BASE] ---@type number
            local YDiff = PlayerPos[1 + INDEX_BASE] - EPtr.Content.O.Pos[1 + INDEX_BASE] ---@type number
            local SqDistance = XDiff * XDiff + YDiff * YDiff ---@type number

            if SqDistance <=
                EPtr.Content.O.ObjType.Radius *
                EPtr.Content.O.ObjType.Radius then
                --[[ collision! --]]
                if bit.band(EPtr.Content.O.Flags, OBJFLAGS_DOOR) ~= 0 then
                    if RequiredObjectsLeft == 0 then
                        if EPtr.Content.O.ObjType.CollectNoise then
                            play_sound(EPtr.Content.O.ObjType.
                            CollectNoise, 255, 128, 1000, false)
                        end
                        RequiredObjectsLeft = -1
                    end
                else
                    EPtr.Content.O.Flags = bit.band(EPtr.Content.O.Flags, bit.bnot(OBJFLAGS_VISIBLE))
                    if EPtr.Content.O.ObjType.CollectNoise then
                        play_sound(EPtr.Content.O.ObjType.CollectNoise,
                            255, 128, 1000, false)
                    end

                    if RequiredObjectsLeft > 0 then
                        RequiredObjectsLeft = RequiredObjectsLeft - 1 ---@type integer
                        if RequiredObjectsLeft == 0 then
                            SetDoorOpen(Lvl)
                        end
                    end
                    TotalObjectsLeft = TotalObjectsLeft - 1
                end
            end
        end

        EPtr = EPtr.Next
    end

    return (function() if key_pressed(allegro5.ALLEGRO_KEY_ESCAPE) then return DEMO_STATE_MAIN_MENU else return CurrentID end end)()
end

local function destroy_game()
    FreeState(LvlState)
    LvlState = nil
end
exports.destroy_game = destroy_game

--[[

  GAMESTATE generation things - see comments in gamestate.h for more
  information

--]]
---@param game GAMESTATE
local function create_new_game(game)
    game.id = newid
    game.init = GameInit
    game.update = GameUpdate
    game.draw = GameDraw
    game.deinit = DeInit
end
exports.create_new_game = create_new_game

---@param game GAMESTATE
local function create_continue_game(game)
    game.id = continueid
    game.init = ContinueInit
    game.update = GameUpdate
    game.draw = GameDraw
    game.deinit = DeInit
end
exports.create_continue_game = create_continue_game

local getters = {
    KeyFlags = function() return KeyFlags end,
    Pusher = function() return Pusher end,
}

local setters = {
    KeyFlags = function(value) KeyFlags = value end,
    Pusher = function(value) Pusher = value end,
}

setmetatable(exports, {
    __index = function(self, key)
        local getter = getters[key]
        if type(getter) == "function" then
            return getter()
        end
        return nil
    end,
    __newindex = function(self, key, value)
        local setter = setters[key]
        if type(setter) == "function" then
            setter(value)
        else
            rawset(self, key, value)
        end
    end
})

return exports
