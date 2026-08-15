#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. arg[0]:gsub("[^/\\]+%.lua", '../../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/cosmic_protector.cpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local SEARCH_OPTIONS = allegro5_lua.kwargs({
    hints = {
        "out/build/x64-Debug/allegro5/allegro5-src",
        "out/build/x64-Release/allegro5/allegro5-src",
        "out/build/Linux-GCC-Debug/allegro5/allegro5-src",
        "out/build/Linux-GCC-Release/allegro5/allegro5-src",
        "out/prepublish/build/allegro5_lua/build.luarocks/allegro5/allegro5-src",
        "allegro5",
    }
})

local ALLEGRO_DEMOS_COSMIC_PROTECTOR_DATA_PATH = os.getenv("ALLEGRO_DEMOS_COSMIC_PROTECTOR_DATA_PATH") or
    allegro5_lua.fs_utils.findFile("demos/cosmic_protector/data", SEARCH_OPTIONS)
common.env.ALLEGRO_DEMOS_COSMIC_PROTECTOR_DATA_PATH = ALLEGRO_DEMOS_COSMIC_PROTECTOR_DATA_PATH

local gui = require("gui")
local joypad_c = require("joypad_c")
local logic = require("logic")
local render = require("render").render
local Debug = require("Debug")
local DisplayResource = require("DisplayResource")
local Entity = require("Entity")
local Game = require("Game")
local Resource = require("Resource")
local ResourceManager = require("ResourceManager").ResourceManager
local Wave = require("Wave").Wave

logic.init()
Entity.init()

local INT_MIN = allegro5_lua.C.INT_MIN

local joypad_find = joypad_c.joypad_find
local joypad_stop_finding = joypad_c.joypad_stop_finding

local do_highscores = gui.do_highscores
local do_menu = gui.do_menu

local entities = logic.entities
local _logic = logic.logic

local debug_message = Debug.debug_message

local done = Game.done
local init = Game.init

local RES_DISPLAY = Resource.RES_DISPLAY
local RES_FPS = Resource.RES_FPS
local RES_GAME_MUSIC = Resource.RES_GAME_MUSIC
local RES_PLAYER = Resource.RES_PLAYER
local RES_TITLE_MUSIC = Resource.RES_TITLE_MUSIC

local voice ---@type ALLEGRO_VOICE
local mixer ---@type ALLEGRO_MIXER

---@param argc integer
---@param argv string[]
---@param arg string
---@return boolean
local function check_arg(argc, argv, arg)
    for i = 1, argc do
        if argv[i] == arg then
            return true
        end
    end
    return false
end

local function game_loop()
    logic.lastUFO = -1
    logic.canUFO = true

    local wave = Wave()

    local step = 0 ---@type integer
    local start = math.floor(allegro5.al_get_time() * 1000) ---@type integer

    while true do
        if #entities <= 0 then
            if not wave:next() then
                -- Won.
                break
            end
        end

        if not _logic(step) then
            break
        end
        render(step)
        allegro5.al_rest(1.0 / 60.0)
        local _end = math.floor(allegro5.al_get_time() * 1000)
        step = _end - start
        start = _end

        if step > 50 then
            step = 50
        end
    end

    for _, e in ipairs(entities) do
        e:__destroy()
    end

    for i = 1, #entities do
        entities[i] = nil
    end
end

local function main(argv)
    local argc = #argv

    if check_arg(argc, argv, "-fullscreen") then
        DisplayResource.useFullScreenMode = true
    end
    if not init() then
        debug_message("Error in initialization.\n")
        return 1
    end

    local rm = ResourceManager.getInstance()
    local player = rm:getData(RES_PLAYER) ---@type Player
    local fps = rm:getData(RES_FPS) ---@type FPS

    local title_music = rm:getData(RES_TITLE_MUSIC) ---@type ALLEGRO_AUDIO_STREAM
    local game_music = rm:getData(RES_GAME_MUSIC) ---@type ALLEGRO_AUDIO_STREAM

    while true do
        if title_music then
            allegro5.al_set_audio_stream_playing(title_music, true)
        end

        joypad_find()

        local _done = false
        while not _done do
            local result = do_menu()
            allegro5.al_rest(0.250)
            if result == 1 then
                do_highscores(INT_MIN)
            elseif result == 2 or result == -1 then
                done()
                _done = true
            else
                break
            end
        end
        if _done then
            break
        end

        if title_music then
            allegro5.al_drain_audio_stream(title_music)
            allegro5.al_rewind_audio_stream(title_music)
        end

        joypad_stop_finding()

        local display = rm:getData(RES_DISPLAY) ---@type ALLEGRO_DISPLAY
        local o = allegro5.al_get_display_orientation(display)
        allegro5.al_set_display_option(display, allegro5.ALLEGRO_SUPPORTED_ORIENTATIONS, o)

        if game_music then
            allegro5.al_set_audio_stream_playing(game_music, true)
        end

        player:load()
        fps:reset()
        game_loop()
        do_highscores(player:getScore())
        player:destroy()

        if game_music then
            allegro5.al_drain_audio_stream(game_music)
            allegro5.al_rewind_audio_stream(game_music)
        end

        allegro5.al_set_display_option(display, allegro5.ALLEGRO_SUPPORTED_ORIENTATIONS,
            allegro5.ALLEGRO_DISPLAY_ORIENTATION_LANDSCAPE)
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
