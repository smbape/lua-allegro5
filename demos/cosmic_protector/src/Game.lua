local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/Game.hpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local joypad_c = require("joypad_c")
local BitmapResource = require("BitmapResource").BitmapResource
local Debug = require("Debug")
local FontResource = require("FontResource").FontResource
local FPS = require("FPS").FPS
local Resource = require("Resource")
local ResourceManager = require("ResourceManager").ResourceManager
local SampleResource = require("SampleResource").SampleResource
local StreamResource = require("StreamResource").StreamResource

local printf = common.printf
local rand = common.rand

local joypad_start = joypad_c.joypad_start

local debug_message = Debug.debug_message

local BMP_NAMES = Resource.BMP_NAMES
local RES_FPS = Resource.RES_FPS
local RES_STREAM_END = Resource.RES_STREAM_END
local RES_STREAM_START = Resource.RES_STREAM_START
local SAMPLE_NAMES = Resource.SAMPLE_NAMES
local STREAM_NAMES = Resource.STREAM_NAMES

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local IS_ANDROID = false
local IS_MSVC = false

if allegro5.ALLEGRO_ANDROID then
    IS_ANDROID = true
    IS_MSVC = false
elseif allegro5.ALLEGRO_MSVC then
    IS_ANDROID = false
    IS_MSVC = true
end

exports.kb_installed = false
exports.joy_installed = false

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/Game.cpp
--]]

-- local kb_installed = false
-- local joy_installed = false

--[[
 - Return the path to user resources (save states, configuration)
 --]]

---@return ALLEGRO_PATH?
local function getDir()
    local dir ---@type ALLEGRO_PATH?

    if IS_ANDROID then
        --[[ Path within the APK, not normal filesystem. --]]
        dir = allegro5.al_create_path_for_directory("data")
    else
        local data_path = common.env.ALLEGRO_DEMOS_COSMIC_PROTECTOR_DATA_PATH ---@type string?
        dir = allegro5.al_create_path_for_directory(data_path)
    end
    return dir
end

local dir ---@type ALLEGRO_PATH?
local path ---@type ALLEGRO_PATH?

---@param fmt string
---@param ... any
---@return string?
local function getResource(fmt, ...)
    local res = string.format(fmt, ...)

    if not dir then
        dir = getDir()
    end

    if path then
        allegro5.al_destroy_path(path)
    end

    path = allegro5.al_create_path(res)
    allegro5.al_rebase_path(dir, path)
    return allegro5.al_path_cstr(path, '/')
end
exports.getResource = getResource


---@return boolean
local function loadResources()
    local DisplayResource = require("DisplayResource").DisplayResource
    local Input = require("Input").Input
    local Player = require("Player").Player

    local rm = ResourceManager.getInstance()
    if not rm:add(DisplayResource()) then
        printf("Failed to create display.\n")
        return false
    end

    --[[ For some reason dsound needs a window... --]]
    if not allegro5.al_install_audio() then
        printf("Failed to install audio.\n")
        --[[ Continue anyway. --]]
    else
        allegro5.al_reserve_samples(16)
    end

    if not rm:add(Player(), false) then
        printf("Failed to create player.\n")
        return false
    end
    if not rm:add(Input()) then
        printf("Failed initializing input.\n")
        return false
    end

    -- Load fonts
    if not rm:add(FontResource(getResource("gfx/large_font.png"))) then
        return false
    end
    if not rm:add(FontResource(getResource("gfx/small_font.png"))) then
        return false
    end

    for i = 1, #BMP_NAMES do
        if not rm:add(BitmapResource(getResource(BMP_NAMES[i]))) then
            printf("Failed to load %s\n", getResource(BMP_NAMES[i]))
            return false
        end
    end

    for i = 1, #SAMPLE_NAMES do
        ---@diagnostic disable-next-line: empty-block
        if not rm:add(SampleResource(getResource(SAMPLE_NAMES[i]))) then
            --[[ Continue anyway. --]]
        end
    end

    for i = 1, #STREAM_NAMES do
        ---@diagnostic disable-next-line: empty-block
        if not rm:add(StreamResource(getResource(STREAM_NAMES[i]))) then
            --[[ Continue anyway. --]]
        end
    end

    if not rm:add(FPS(), false) then
        printf("Failed to create fps.\n")
        return false
    end

    joypad_start()

    return true
end
exports.loadResources = loadResources

---@return boolean
local function init()
    if not allegro5.al_init() then
        debug_message("Error initialising Allegro.\n")
        return false
    end
    allegro5.al_set_org_name("Allegro")
    allegro5.al_set_app_name("Cosmic Protector")
    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    allegro5.al_init_acodec_addon()
    allegro5.al_init_primitives_addon()
    if allegro5.ALLEGRO_ANDROID then
        allegro5.al_android_set_apk_file_interface() ---@diagnostic disable-line: undefined-field
    end

    if not loadResources() then
        debug_message("Error loading resources.\n")
        return false
    end

    return true
end
exports.init = init

local function done()
    -- Free resources
    allegro5.al_stop_samples()
    local rm = ResourceManager.getInstance()
    for i = RES_STREAM_START, RES_STREAM_END - INDEX_BASE do
        local s = rm:getData(i) ---@type ALLEGRO_AUDIO_STREAM?
        if s then
            allegro5.al_set_audio_stream_playing(s, false)
        end
    end

    ResourceManager.getInstance():destroy()
end
exports.done = done

-- Returns a random number between lo and hi
---@param lo number
---@param hi number
---@return number
local function randf(lo, hi)
    local range = hi - lo
    local n = rand() % 10000
    local f = range * n / 10000.0
    return lo + f
end
exports.randf = randf

return exports
