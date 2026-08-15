---@class global
---@field fullscreen integer selects fullscreen or windowed mode
---@field bit_depth integer screen colour depth (15/16/24/32) Note that this is ignored when in windowed mode and the desktop colour depth can be retrieved.
---@field screen_width integer horizontal screen resolution
---@field screen_height integer vertical screen resolution
---@field screen_orientation integer
---@field window_width integer remember last window width
---@field window_height integer remember last window height
---@field screen_samples integer super-sampling
---@field use_vsync integer enables/disables vsync-ing
---@field logic_framerate integer target logic framerate
---@field max_frame_skip integer max number of skipped logic frames if the CPU isn't fast enough
---@field limit_framerate integer enables/disables unlimited framerate
---@field display_framerate integer enables/disables FPS counter
---@field reduce_cpu_usage integer enables/disables power saving by giving up the CPU when not needed
---@field sound_volume integer sound volume in range [0,10]
---@field music_volume integer music volume in range [0,10]
---@field controller_id integer ID of the selected input controller
---@field shadow_offset integer Offset of the text shadow in game menus as number of pixels.
---@field controller [VCONTROLLER?, VCONTROLLER?] Array of available input controllers. New controllers may be added here in the future.
---@field config_path? string Absolute path of the config file.
---@field data_path? string Absolute path of the datafile.
---@field screen? ALLEGRO_DISPLAY Absolute path of the datafile.
---@field demo_font? ALLEGRO_FONT The main menu font (monochrome).
---@field demo_font_logo? ALLEGRO_FONT The big title font (coloured).
---@field plain_font? ALLEGRO_FONT Font made of default allegro font (monochrome).
---@field demo_data? DATA_ENTRY[]
local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/global.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local background_scroller ---@module 'background_scroller'
local common = require("examples.common")
local defines = require("defines")
local demodata = require("demodata")
local framework ---@module 'framework'
local game ---@module 'game'
local music ---@module 'music'
local vcontroller = require("vcontroller")

local init_background ---@type function

local load_game_resources ---@type fun(datapath: string) : string?
local unload_game_resources ---@type function

local set_music_volume ---@type fun(v: number)
local set_sound_volume ---@type fun(v: number)

exports.init = function()
    background_scroller = require("background_scroller")
    framework = require("framework")
    game = require("game")
    music = require("music")

    init_background = background_scroller.init_background

    load_game_resources = game.load_game_resources
    unload_game_resources = game.unload_game_resources

    set_music_volume = music.set_music_volume
    set_sound_volume = music.set_sound_volume
end

local new_table = common.new_table

local DEMO_ERROR_ALLEGRO = defines.DEMO_ERROR_ALLEGRO
local DEMO_ERROR_DATA = defines.DEMO_ERROR_DATA
local DEMO_ERROR_GAMEDATA = defines.DEMO_ERROR_GAMEDATA
local DEMO_ERROR_GFX = defines.DEMO_ERROR_GFX
local DEMO_ERROR_MEMORY = defines.DEMO_ERROR_MEMORY
local DEMO_ERROR_TRIPLEBUFFER = defines.DEMO_ERROR_TRIPLEBUFFER
local DEMO_ERROR_VIDEOMEMORY = defines.DEMO_ERROR_VIDEOMEMORY
local DEMO_OK = defines.DEMO_OK

local DEMO_BMP_BACK = demodata.DEMO_BMP_BACK
local DEMO_BMP_BANANAS = demodata.DEMO_BMP_BANANAS
local DEMO_BMP_CHERRIES = demodata.DEMO_BMP_CHERRIES
local DEMO_BMP_CLOUD = demodata.DEMO_BMP_CLOUD
local DEMO_BMP_DOOROPEN = demodata.DEMO_BMP_DOOROPEN
local DEMO_BMP_DOORSHUT = demodata.DEMO_BMP_DOORSHUT
local DEMO_BMP_EXITSIGN = demodata.DEMO_BMP_EXITSIGN
local DEMO_BMP_GRASS = demodata.DEMO_BMP_GRASS
local DEMO_BMP_ICE = demodata.DEMO_BMP_ICE
local DEMO_BMP_ICECREAM = demodata.DEMO_BMP_ICECREAM
local DEMO_BMP_ICETIP = demodata.DEMO_BMP_ICETIP
local DEMO_BMP_ORANGE = demodata.DEMO_BMP_ORANGE
local DEMO_BMP_SKATEFAST = demodata.DEMO_BMP_SKATEFAST
local DEMO_BMP_SKATEMED = demodata.DEMO_BMP_SKATEMED
local DEMO_BMP_SKATER1 = demodata.DEMO_BMP_SKATER1
local DEMO_BMP_SKATER2 = demodata.DEMO_BMP_SKATER2
local DEMO_BMP_SKATER3 = demodata.DEMO_BMP_SKATER3
local DEMO_BMP_SKATER4 = demodata.DEMO_BMP_SKATER4
local DEMO_BMP_SKATESLOW = demodata.DEMO_BMP_SKATESLOW
local DEMO_BMP_SOIL = demodata.DEMO_BMP_SOIL
local DEMO_BMP_SWEET = demodata.DEMO_BMP_SWEET
local DEMO_BMP_WATER = demodata.DEMO_BMP_WATER
local DEMO_DATA_COUNT = demodata.DEMO_DATA_COUNT
local DEMO_FONT = demodata.DEMO_FONT
local DEMO_FONT_LOGO = demodata.DEMO_FONT_LOGO
local DEMO_MIDI_INGAME = demodata.DEMO_MIDI_INGAME
local DEMO_MIDI_INTRO = demodata.DEMO_MIDI_INTRO
local DEMO_MIDI_MENU = demodata.DEMO_MIDI_MENU
local DEMO_MIDI_SUCCESS = demodata.DEMO_MIDI_SUCCESS
local DEMO_SAMPLE_BUTTON = demodata.DEMO_SAMPLE_BUTTON
local DEMO_SAMPLE_DING = demodata.DEMO_SAMPLE_DING
local DEMO_SAMPLE_DOOROPEN = demodata.DEMO_SAMPLE_DOOROPEN
local DEMO_SAMPLE_POP = demodata.DEMO_SAMPLE_POP
local DEMO_SAMPLE_SKATING = demodata.DEMO_SAMPLE_SKATING
local DEMO_SAMPLE_WAVE = demodata.DEMO_SAMPLE_WAVE
local DEMO_SAMPLE_WELCOME = demodata.DEMO_SAMPLE_WELCOME

local VCONTROLLER = vcontroller.VCONTROLLER

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ Some configuration settings. All of these variables are recorded
   in the configuration file. --]]
---@type integer
local fullscreen = 0 --[[ selects fullscreen or windowed mode --]]
---@type integer
local bit_depth = 0 --[[ screen colour depth (15/16/24/32)
                                    Note that this is ignored when in windowed
                                    mode and the desktop colour depth can be
                                    retrieved. --]]
---@type integer
local screen_width = 0 --[[ horizontal screen resolution --]]
---@type integer
local screen_height = 0 --[[ vertical screen resolution --]]
---@type integer
local screen_orientation = 0
---@type integer
local window_width = 0 --[[ remember last window width --]]
---@type integer
local window_height = 0 --[[ remember last window height --]]
---@type integer
local screen_samples = 0 --[[ super-sampling --]]
---@type integer
local use_vsync = 0 --[[ enables/disables vsync-ing --]]
---@type integer
local logic_framerate = 0 --[[ target logic framerate --]]
---@type integer
local max_frame_skip = 0 --[[ max number of skipped logic frames if
                                    the CPU isn't fast enough --]]
---@type integer
local limit_framerate = 0 --[[ enables/disables unlimited framerate --]]
---@type integer
local display_framerate = 0 --[[ enables/disables FPS counter --]]
---@type integer
local reduce_cpu_usage = 0 --[[ enables/disables power saving by giving
                                    up the CPU when not needed --]]
---@type integer
local sound_volume = 0 --[[ sound volume in range [0,10] --]]
---@type integer
local music_volume = 0 --[[ music volume in range [0,10] --]]
---@type integer
local controller_id = 0 --[[ ID of the selected input controller --]]

--[[ Offset of the text shadow in game menus as number of pixels. --]]
---@type integer
local shadow_offset = 0

--[[ Array of available input controllers. New controllers may be added
   here in the future. --]]
local controller ---@type [VCONTROLLER?, VCONTROLLER?]

--[[ Absolute path of the config file. --]]
local config_path ---@type string

--[[ Absolute path of the datafile. --]]
local data_path ---@type string

--[[ The main menu font (monochrome). --]]
-- local demo_font

--[[ The big title font (coloured). --]]
-- local demo_font_logo

--[[ Font made of default allegro font (monochrome). --]]
-- local plain_font = demo_font


--[[
   Facade for text output functions. Implements a common interface for text
   output using Allegro's or AllegroGL's text output functions.
   Text alignment is selected with a parameter.

   Parameters:
      ALLEGRO_BITMAP *canvas, int x, int y, int col and char *format have
         exactly the same meaning as in the equivalent Allegro built-in
         text output functions.
      FONT *font can be either plain Allegro font or a font converted with
      AllegroGL's allegro_gl_convert_allegro_font_ex().
      int align - defines alignemnt: 0 = left, 1 = right, 2 = centre

   Returns:
      nothing
--]]
local demo_textprintf_ex
local demo_textprintf
local demo_textprintf_right
local demo_textprintf_centre
local demo_textout ---@type function
local demo_textout_right ---@type function
local demo_textout_centre ---@type function


---@class DATA_ENTRY
---@field id integer
---@field type? string
---@field path? string
---@field subfolder? string
---@field name? string
---@field ext? string
---@field size integer
---@field dat? any
---@overload fun(id? : integer, type? : string, path? : string, subfolder? : string, name? : string, ext? : string, size? : integer, dat? : any): DATA_ENTRY
local DATA_ENTRY = common.class({
    __name = "DATA_ENTRY",

    ---@param self DATA_ENTRY
    ---@param id? integer
    ---@param type? string
    ---@param path? string
    ---@param subfolder? string
    ---@param name? string
    ---@param ext? string
    ---@param size? integer
    ---@param dat? any
    __init__ = function(self, id, type, path, subfolder, name, ext, size, dat)
        if id == nil then id = 0 end
        if size == nil then size = 0 end
        self.id = id
        self.type = type
        self.path = path
        self.subfolder = subfolder
        self.name = name
        self.ext = ext
        self.size = size
        self.dat = dat
    end
})
exports.DATA_ENTRY = DATA_ENTRY

local unload_data_entries

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/global.c
--]]

--[[ Default values of some config varables --]]
if allegro5.ALLEGRO_IPHONE then
    fullscreen = 1
    controller_id = 1
else
    fullscreen = 0
    controller_id = 0
end
bit_depth = 32
screen_width = 640
screen_height = 480
screen_orientation = allegro5.ALLEGRO_DISPLAY_ORIENTATION_0_DEGREES
window_width = 640
window_height = 480
screen_samples = 1
use_vsync = 0
logic_framerate = 100
max_frame_skip = 5
limit_framerate = 1
display_framerate = 1
reduce_cpu_usage = 1
sound_volume = 8
music_volume = 8

shadow_offset = 2

controller = new_table(VCONTROLLER, 2)
exports.controller = controller

-- local config_path
-- local data_path
local demo_data ---@type DATA_ENTRY[]?

local screen ---@type ALLEGRO_DISPLAY?

local GameError ---@type string?

local load_data

--[[
   Converts an error code to an error description.

   Parameters:
      int id - error code (see defines.h)

   Returns:
      String containing the description of the error code.
--]]
local function demo_error(id)
    if id == DEMO_ERROR_ALLEGRO then
        return "Allegro error"
    elseif id == DEMO_ERROR_GFX then
        return "can't find suitable screen update driver"
    elseif id == DEMO_ERROR_MEMORY then
        return "ran out of memory"
    elseif id == DEMO_ERROR_VIDEOMEMORY then
        return "not enough VRAM"
    elseif id == DEMO_ERROR_TRIPLEBUFFER then
        return "triple buffering not supported"
    elseif id == DEMO_ERROR_DATA then
        return "can't load menu data"
    elseif id == DEMO_ERROR_GAMEDATA then
        return GameError
    elseif id == DEMO_OK then
        return "OK"
    else
        return "unknown"
    end
end
exports.demo_error = demo_error


---@param cfg ALLEGRO_CONFIG
---@param section string
---@param name string
---@param def integer
---@return integer
local function get_config_int(cfg, section, name, def)
    local v = allegro5.al_get_config_value(cfg, section, name)
    if v and v ~= "" then
        local value = tonumber(v, 10)
        if value ~= nil then
            return value
        end
    end
    return def
end
exports.get_config_int = get_config_int


---@param cfg ALLEGRO_CONFIG
---@param section string
---@param name string
---@param val integer
local function set_config_int(cfg, section, name, val)
    local buf = string.format("%d", val)
    allegro5.al_set_config_value(cfg, section, name, buf)
end
exports.set_config_int = set_config_int


--[[
   Reads global configuration settings from a config file.

   Parameters:
      char *config - Path to the config file.

   Returns:
      nothing
--]]
---@param config string
local function read_global_config(config)
    local c = allegro5.al_load_config_file(config)
    if not c then
        c = allegro5.al_create_config()
    end
    if not c then
        return
    end

    fullscreen = get_config_int(c, "GFX", "fullscreen", fullscreen)
    bit_depth = get_config_int(c, "GFX", "bit_depth", bit_depth)
    screen_width = get_config_int(c, "GFX", "screen_width", screen_width)
    screen_height = get_config_int(c, "GFX", "screen_height", screen_height)
    window_width = get_config_int(c, "GFX", "window_width", window_height)
    window_height = get_config_int(c, "GFX", "window_height", screen_height)
    screen_samples = get_config_int(c, "GFX", "samples", screen_samples)
    use_vsync = get_config_int(c, "GFX", "vsync", use_vsync)

    logic_framerate =
        get_config_int(c, "TIMING", "logic_framerate", logic_framerate)
    limit_framerate =
        get_config_int(c, "TIMING", "limit_framerate", limit_framerate)
    max_frame_skip =
        get_config_int(c, "TIMING", "max_frame_skip", max_frame_skip)
    display_framerate =
        get_config_int(c, "TIMING", "display_framerate", display_framerate)
    reduce_cpu_usage =
        get_config_int(c, "TIMING", "reduce_cpu_usage", reduce_cpu_usage)

    sound_volume = get_config_int(c, "SOUND", "sound_volume", sound_volume)
    music_volume = get_config_int(c, "SOUND", "music_volume", music_volume)

    set_sound_volume(sound_volume / 10.0)
    set_music_volume(music_volume / 10.0)

    controller_id = get_config_int(c, "CONTROLS", "controller_id", controller_id)

    allegro5.al_destroy_config(c)
end
exports.read_global_config = read_global_config

--[[
   Writes global configuration settings to a config file.

   Parameters:
      char *config - Path to the config file.

   Returns:
      nothing
--]]
---@param config string
local function write_global_config(config)
    local c = allegro5.al_load_config_file(config)
    if not c then
        c = allegro5.al_create_config()
    end
    if not c then
        return
    end

    set_config_int(c, "GFX", "fullscreen", fullscreen)
    set_config_int(c, "GFX", "bit_depth", bit_depth)
    set_config_int(c, "GFX", "screen_width", screen_width)
    set_config_int(c, "GFX", "screen_height", screen_height)
    set_config_int(c, "GFX", "window_width", window_width)
    set_config_int(c, "GFX", "window_height", window_height)
    set_config_int(c, "GFX", "samples", screen_samples)
    set_config_int(c, "GFX", "vsync", use_vsync)

    set_config_int(c, "TIMING", "logic_framerate", logic_framerate)
    set_config_int(c, "TIMING", "max_frame_skip", max_frame_skip)
    set_config_int(c, "TIMING", "limit_framerate", limit_framerate)
    set_config_int(c, "TIMING", "display_framerate", display_framerate)
    set_config_int(c, "TIMING", "reduce_cpu_usage", reduce_cpu_usage)

    set_config_int(c, "SOUND", "sound_volume", sound_volume)
    set_config_int(c, "SOUND", "music_volume", music_volume)

    set_config_int(c, "CONTROLS", "controller_id", controller_id)

    allegro5.al_save_config_file(config, c)
    allegro5.al_destroy_config(c)
end
exports.write_global_config = write_global_config

---@param d DATA_ENTRY[]
---@param id integer
---@param _type string
---@param path string
---@param subfolder string
---@param name string
---@param ext string
---@param size integer
---@return boolean
local function _load(d, id, _type, path, subfolder, name, ext, size)
    local spath = string.format("%s/%s/%s.%s", path, subfolder, name, ext)
    io.write(string.format("Loading %s...\n", spath))
    if _type == "font" then
        d[id + INDEX_BASE].dat = allegro5.al_load_font(spath, size, 0)
    end
    if _type == "bitmap" then
        d[id + INDEX_BASE].dat = allegro5.al_load_bitmap(spath)
    end
    if _type == "sample" then
        d[id + INDEX_BASE].dat = allegro5.al_load_sample(spath)
    end
    if _type == "music" then
        d[id + INDEX_BASE].dat = allegro5.al_load_audio_stream(spath, 2, 4096)
    end
    if d[id + INDEX_BASE].dat == nil then
        io.write(string.format("Failed loading %s.\n", name))
    end
    d[id + INDEX_BASE].type = _type
    d[id + INDEX_BASE].path = path
    d[id + INDEX_BASE].subfolder = subfolder
    d[id + INDEX_BASE].name = name
    d[id + INDEX_BASE].ext = ext
    d[id + INDEX_BASE].size = size
    return d[id + INDEX_BASE].dat ~= nil
end

--[[
   Switches the gfx mode to settings defined by the global variables
   declared in this file and reloads all data if necessary.

   Parameters:
      none

   Returns:
      Error code: DEMO_OK on succes, otherwise the code of the error
      that caused the function to fail. See defines.h for a list of
      possible error codes.
--]]
---@return integer
local function change_gfx_mode()
    local flags = 0 ---@type integer

    --[[ Select appropriate (fullscreen or windowed) gfx mode driver. --]]
    if fullscreen == 0 then
        flags = bit.bor(flags, bit.bor(allegro5.ALLEGRO_WINDOWED, allegro5.ALLEGRO_RESIZABLE))
        screen_width = window_width
        screen_height = window_height
    elseif fullscreen == 1 then
        flags = bit.bor(flags, allegro5.ALLEGRO_FULLSCREEN_WINDOW)
    else
        flags = bit.bor(flags, allegro5.ALLEGRO_FULLSCREEN)
    end

    if screen then
        allegro5.al_destroy_display(screen)
    end

    allegro5.al_set_new_display_flags(flags)

    -- May be a good idea, but need to add a border to textures for it.
    -- al_set_new_bitmap_flags(ALLEGRO_MIN_LINEAR | ALLEGRO_MAG_LINEAR);

    if screen_samples > 1 then
        allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLE_BUFFERS, 1, allegro5.ALLEGRO_SUGGEST)
        allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLES, screen_samples, allegro5.ALLEGRO_SUGGEST)
    else
        allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLE_BUFFERS, 0, allegro5.ALLEGRO_SUGGEST)
        allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLES, 0, allegro5.ALLEGRO_SUGGEST)
    end

    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SUPPORTED_ORIENTATIONS,
        allegro5.ALLEGRO_DISPLAY_ORIENTATION_LANDSCAPE, allegro5.ALLEGRO_SUGGEST)

    --[[ Attempt to set the selected colour depth and gfx mode. --]]
    screen = allegro5.al_create_display(screen_width, screen_height)
    if not screen then
        return DEMO_ERROR_ALLEGRO
    end
    allegro5.al_set_window_constraints(screen, 320, 320, 0, 0)

    screen_width = allegro5.al_get_display_width(screen)
    screen_height = allegro5.al_get_display_height(screen)
    screen_orientation = allegro5.ALLEGRO_DISPLAY_ORIENTATION_90_DEGREES

    allegro5.al_register_event_source(framework.event_queue, allegro5.al_get_display_event_source(screen))

    --[[ blank display now, before doing any more complicated stuff --]]
    allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))

    --[[ Attempt to load game data. --]]
    local ret = load_data()

    --[[ If loading was successful, initialize the background scroller module. --]]
    if ret == DEMO_OK then
        init_background()
    end

    return ret
end
exports.change_gfx_mode = change_gfx_mode

---@param path string
---@return DATA_ENTRY[]
local function load_data_entries(path)
    local d = new_table(DATA_ENTRY, DEMO_DATA_COUNT + 1)

    _load(d, DEMO_BMP_BACK, "bitmap", path, "menu", "back", "png", 0)
    _load(d, DEMO_FONT, "font", path, "menu", "cancunsmall", "png", 0)
    _load(d, DEMO_FONT_LOGO, "font", path, "menu", "logofont", "png", 0)
    _load(d, DEMO_MIDI_INGAME, "music", path, "menu", "skate2", "ogg", 0)
    _load(d, DEMO_MIDI_INTRO, "music", path, "menu", "intro_music", "ogg", 0)
    _load(d, DEMO_MIDI_MENU, "music", path, "menu", "menu_music", "ogg", 0)
    _load(d, DEMO_MIDI_SUCCESS, "music", path, "menu", "endoflevel", "ogg", 0)
    _load(d, DEMO_SAMPLE_BUTTON, "sample", path, "menu", "button", "ogg", 0)
    _load(d, DEMO_SAMPLE_WELCOME, "sample", path, "menu", "welcome", "ogg", 0)
    _load(d, DEMO_SAMPLE_SKATING, "sample", path, "audio", "skating", "ogg", 0)
    _load(d, DEMO_SAMPLE_WAVE, "sample", path, "audio", "wave", "ogg", 0)
    _load(d, DEMO_SAMPLE_DING, "sample", path, "audio", "ding", "ogg", 0)
    _load(d, DEMO_SAMPLE_DOOROPEN, "sample", path, "audio", "dooropen", "ogg", 0)
    _load(d, DEMO_SAMPLE_POP, "sample", path, "audio", "pop", "ogg", 0)

    _load(d, DEMO_BMP_BANANAS, "bitmap", path, "graphics", "bananas", "png", 0)
    _load(d, DEMO_BMP_CHERRIES, "bitmap", path, "graphics", "cherries", "png", 0)
    _load(d, DEMO_BMP_CLOUD, "bitmap", path, "graphics", "cloud", "png", 0)
    _load(d, DEMO_BMP_DOOROPEN, "bitmap", path, "graphics", "dooropen", "png", 0)
    _load(d, DEMO_BMP_DOORSHUT, "bitmap", path, "graphics", "doorshut", "png", 0)
    _load(d, DEMO_BMP_EXITSIGN, "bitmap", path, "graphics", "exitsign", "png", 0)
    _load(d, DEMO_BMP_GRASS, "bitmap", path, "graphics", "grass", "png", 0)
    _load(d, DEMO_BMP_ICECREAM, "bitmap", path, "graphics", "icecream", "png", 0)
    _load(d, DEMO_BMP_ICE, "bitmap", path, "graphics", "ice", "png", 0)
    _load(d, DEMO_BMP_ICETIP, "bitmap", path, "graphics", "icetip", "png", 0)
    _load(d, DEMO_BMP_ORANGE, "bitmap", path, "graphics", "orange", "png", 0)
    _load(d, DEMO_BMP_SKATEFAST, "bitmap", path, "graphics", "skatefast", "png", 0)
    _load(d, DEMO_BMP_SKATEMED, "bitmap", path, "graphics", "skatemed", "png", 0)
    _load(d, DEMO_BMP_SKATER1, "bitmap", path, "graphics", "skater1", "png", 0)
    _load(d, DEMO_BMP_SKATER2, "bitmap", path, "graphics", "skater2", "png", 0)
    _load(d, DEMO_BMP_SKATER3, "bitmap", path, "graphics", "skater3", "png", 0)
    _load(d, DEMO_BMP_SKATER4, "bitmap", path, "graphics", "skater4", "png", 0)
    _load(d, DEMO_BMP_SKATESLOW, "bitmap", path, "graphics", "skateslow", "png", 0)
    _load(d, DEMO_BMP_SOIL, "bitmap", path, "graphics", "soil", "png", 0)
    _load(d, DEMO_BMP_SWEET, "bitmap", path, "graphics", "sweet", "png", 0)
    _load(d, DEMO_BMP_WATER, "bitmap", path, "graphics", "water", "png", 0)

    return d
end

---@param entries DATA_ENTRY[]
unload_data_entries = function(entries)
    for _, data in ipairs(entries) do
        if data.dat then
            if data.type == "bitmap" then
                allegro5.al_destroy_bitmap(data.dat)
            end
            if data.type == "font" then
                allegro5.al_destroy_font(data.dat)
            end
            if data.type == "sample" then
                allegro5.al_destroy_sample(data.dat)
            end
            if data.type == "music" then
                allegro5.al_destroy_audio_stream(data.dat)
            end
        end
    end
end
exports.unload_data_entries = unload_data_entries

---@return integer
load_data = function()
    if demo_data then
        return DEMO_OK
    end

    --[[ Load the data for the game menus. --]]
    demo_data = load_data_entries(data_path)
    if demo_data == nil then
        return DEMO_ERROR_DATA
    end

    --[[ Load other game resources. --]]
    GameError = load_game_resources(data_path)
    if GameError then
        return DEMO_ERROR_GAMEDATA
    end

    return DEMO_OK
end
exports.load_data = load_data


--[[
   Unloads all game data. Required before changing gfx mode and before
   shutting down the framework.

   Parameters:
      none

   Returns:
      nothing
--]]
local function unload_data()
    if demo_data then
        unload_data_entries(demo_data)
        unload_game_resources()
        demo_data = nil
    end
end
exports.unload_data = unload_data


---@param f ALLEGRO_FONT
---@param s string
---@param x integer
---@param y integer
---@param color ALLEGRO_COLOR
demo_textout = function(f, s, x, y, color)
    demo_textprintf(f, x, y, color, "%s", s)
end
exports.demo_textout = demo_textout


---@param f ALLEGRO_FONT
---@param s string
---@param x integer
---@param y integer
---@param color ALLEGRO_COLOR
demo_textout_right = function(f, s, x, y, color)
    demo_textprintf_right(f, x, y, color, "%s", s)
end
exports.demo_textout_right = demo_textout_right


---@param f ALLEGRO_FONT
---@param s string
---@param x integer
---@param y integer
---@param color ALLEGRO_COLOR
demo_textout_centre = function(f, s, x, y, color)
    demo_textprintf_centre(f, x, y, color, "%s", s)
end
exports.demo_textout_centre = demo_textout_centre

---@param font ALLEGRO_FONT
---@param x integer
---@param y integer
---@param col ALLEGRO_COLOR
---@param format string
---@param ... any
demo_textprintf_centre = function(font, x, y, col, format, ...)
    demo_textprintf_ex(font, x, y, col, 2, format, ...)
end
exports.demo_textprintf_centre = demo_textprintf_centre


---@param font ALLEGRO_FONT
---@param x integer
---@param y integer
---@param col ALLEGRO_COLOR
---@param format string
---@param ... any
demo_textprintf_right = function(font, x, y, col, format, ...)
    demo_textprintf_ex(font, x, y, col, 1, format, ...)
end
exports.demo_textprintf_right = demo_textprintf_right


---@param font ALLEGRO_FONT
---@param x integer
---@param y integer
---@param col ALLEGRO_COLOR
---@param format string
---@param ... any
demo_textprintf = function(font, x, y, col, format, ...)
    demo_textprintf_ex(font, x, y, col, 0, format, ...)
end
exports.demo_textprintf = demo_textprintf

---@param font ALLEGRO_FONT
---@param x integer
---@param y integer
---@param col ALLEGRO_COLOR
---@param align integer
---@param format string
---@param ... any
demo_textprintf_ex = function(font, x, y, col, align, format, ...)
    local buf = string.format(format, ...)

    if align == 0 then
        allegro5.al_draw_text(font, col, x, y, allegro5.ALLEGRO_ALIGN_LEFT, buf)
    elseif align == 1 then
        allegro5.al_draw_text(font, col, x, y, allegro5.ALLEGRO_ALIGN_RIGHT, buf)
    elseif align == 2 then
        allegro5.al_draw_text(font, col, x, y, allegro5.ALLEGRO_ALIGN_CENTRE, buf)
    end
end
exports.demo_textprintf_ex = demo_textprintf_ex


--[[
   Custom text output function. Similar to the Allegro's built-in functions
   except that text alignment is selected with a parameter and the text is
   printed with a black shadow. Offset of the shadow is defined with the
   shadow_offset variable.

   Parameters:
      ALLEGRO_BITMAP *canvas, FONT *font, int x, int y, int col and char *text have
         exactly the same meaning as in the equivalent Allegro built-in
         text output functions.
      int align - defines alignemnt: 0 = left, 1 = right, 2 = centre

   Returns:
      nothing
--]]
---@param font ALLEGRO_FONT
---@param x integer
---@param y integer
---@param col ALLEGRO_COLOR
---@param align integer
---@param format string
---@param ... any
local function shadow_textprintf(font, x, y, col, align, format, ...)
    local buf = string.format(format, ...)

    demo_textprintf_ex(font, x + shadow_offset, y + shadow_offset, allegro5.al_map_rgba(0, 0, 0, 128),
        align, "%s", buf)
    demo_textprintf_ex(font, x, y, col, align, "%s", buf)
end
exports.shadow_textprintf = shadow_textprintf


local getters = {
    fullscreen = function() return fullscreen end,
    bit_depth = function() return bit_depth end,
    screen_width = function() return screen_width end,
    screen_height = function() return screen_height end,
    screen_orientation = function() return screen_orientation end,
    window_width = function() return window_width end,
    window_height = function() return window_height end,
    screen_samples = function() return screen_samples end,
    use_vsync = function() return use_vsync end,
    logic_framerate = function() return logic_framerate end,
    max_frame_skip = function() return max_frame_skip end,
    limit_framerate = function() return limit_framerate end,
    display_framerate = function() return display_framerate end,
    reduce_cpu_usage = function() return reduce_cpu_usage end,
    sound_volume = function() return sound_volume end,
    music_volume = function() return music_volume end,
    controller_id = function() return controller_id end,
    shadow_offset = function() return shadow_offset end,
    config_path = function() return config_path end,
    data_path = function() return data_path end,
    demo_font = function() if demo_data then return demo_data[DEMO_FONT + INDEX_BASE].dat end end,
    demo_font_logo = function() if demo_data then return demo_data[DEMO_FONT_LOGO + INDEX_BASE].dat end end,
    screen = function() return screen end,
    demo_data = function() return demo_data end,
}

getters.plain_font = getters.demo_font

local setters = {
    fullscreen = function(value) fullscreen = value end,
    bit_depth = function(value) bit_depth = value end,
    screen_width = function(value) screen_width = value end,
    screen_height = function(value) screen_height = value end,
    screen_orientation = function(value) screen_orientation = value end,
    window_width = function(value) window_width = value end,
    window_height = function(value) window_height = value end,
    screen_samples = function(value) screen_samples = value end,
    use_vsync = function(value) use_vsync = value end,
    logic_framerate = function(value) logic_framerate = value end,
    max_frame_skip = function(value) max_frame_skip = value end,
    limit_framerate = function(value) limit_framerate = value end,
    display_framerate = function(value) display_framerate = value end,
    reduce_cpu_usage = function(value) reduce_cpu_usage = value end,
    sound_volume = function(value) sound_volume = value end,
    music_volume = function(value) music_volume = value end,
    controller_id = function(value) controller_id = value end,
    shadow_offset = function(value) shadow_offset = value end,
    config_path = function(value) config_path = value end,
    data_path = function(value) data_path = value end,
    demo_font = function(value) demo_data = value[DEMO_FONT].dat end, ---@diagnostic disable-line: no-unknown
    demo_font_logo = function(value) demo_data = value[DEMO_FONT_LOGO].dat end, ---@diagnostic disable-line: no-unknown
    screen = function(value) screen = value end,
    demo_data = function(value) demo_data = value end,
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
