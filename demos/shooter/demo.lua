---@class demo
---@field max_fps boolean
---@field cheat boolean
---@field SCREEN_W integer
---@field SCREEN_H integer
local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/shooter/demo.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("examples.common")
local a4_aux = require("demos.speed.a4_aux")
local data_m ---@module "data"
local expl ---@module "expl"
local game ---@module "game"
local title ---@module "title"

local new_table = common.new_table

local INDEX_BASE = 1 -- lua is 1-based indexed

local clock = allegro5_lua.C.clock
local CLOCKS_PER_SEC = allegro5_lua.C.CLOCKS_PER_SEC

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi") ---@diagnostic disable-line: no-unknown
    clock = ffi.C.clock ---@type fun() : integer
end

--[[ al_get_current_time() measures wallclock time - but for the benchmark
 - result we prefer CPU time so clock() is better.
 --]]
local function current_clock()
   local c = clock()
   return tonumber(c) / CLOCKS_PER_SEC
end

local allegro_init = a4_aux.allegro_init
local allegro_message = a4_aux.allegro_message
local install_keyboard = a4_aux.install_keyboard
local install_mouse = a4_aux.install_mouse
local install_sound = a4_aux.install_sound
local install_timer = a4_aux.install_timer
local keypressed = a4_aux.keypressed
local makecol = a4_aux.makecol
local play_sample = a4_aux.play_sample
local poll_input = a4_aux.poll_input
local rest = a4_aux.rest
local stop_midi = a4_aux.stop_midi
local stretch_blit = a4_aux.stretch_blit

local INTRO_SPL ---@type integer
local INTRO_ANIM ---@type integer
local data ---@type DATAFILE[]
local data_load ---@type fun()

local destroy_explosions ---@type fun()
local generate_explosions ---@type fun()

local title_screen ---@type fun() -> boolean

local play_game ---@type fun()

function exports.init()
    data_m = require("data")
    expl = require("expl")
    game = require("game")
    title = require("title")

    data_m.init()

    INTRO_SPL = data_m.INTRO_SPL
    INTRO_ANIM = data_m.INTRO_ANIM
    data = data_m.data
    data_load = data_m.data_load

    destroy_explosions = expl.destroy_explosions
    generate_explosions = expl.generate_explosions

    play_game = game.play_game

    title_screen = title.title_screen
end

local max_fps = false
local cheat = false
local PAL_SIZE = 256; exports.PAL_SIZE = PAL_SIZE

---@class PALETTE
---@field rgb ALLEGRO_COLOR[]
---@overload fun(rgb? : ALLEGRO_COLOR[]): PALETTE
local PALETTE = common.class({
    __name = "PALETTE",

    ---@param self PALETTE
    ---@param rgb? ALLEGRO_COLOR[]
    __init__ = function(self, rgb)
        if rgb == nil then rgb = new_table(allegro5.ALLEGRO_COLOR, PAL_SIZE) end
        self.rgb = rgb
    end
})
exports.PALETTE = PALETTE
local SCREEN_W = function() return allegro5.al_get_display_width(allegro5.al_get_current_display()) end
local SCREEN_H = function() return allegro5.al_get_display_height(allegro5.al_get_current_display()) end


--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/shooter/demo.c
--]]

--[[ command line options --]]
cheat = false
local jumpstart = false

max_fps = false
local palette ---@type PALETTE?

---@param p integer
---@return ALLEGRO_COLOR
local function get_palette(p)
    if not palette then
        return makecol(0, 0, 0)
    end
    return palette.rgb[p + INDEX_BASE]
end
exports.get_palette = get_palette

---@param p PALETTE
local function set_palette(p)
    palette = p
end
exports.set_palette = set_palette



---@param skip integer
local function fade_out(skip)
    local capture = allegro5.al_create_bitmap(SCREEN_W(), SCREEN_H())
    allegro5.al_set_target_bitmap(capture)
    allegro5.al_draw_bitmap(allegro5.al_get_backbuffer(a4_aux.screen), 0, 0, 0)
    allegro5.al_set_target_backbuffer(a4_aux.screen)

    local steps = math.floor(128 / skip) ---@type integer
    if steps < 1 then
        steps = 1
    end
    local t0 = allegro5.al_get_time()
    for i = 0, steps - INDEX_BASE do
        allegro5.al_rest(t0 + (i + 1) / 120.0 - allegro5.al_get_time())
        local fade = allegro5.al_map_rgba_f(0, 0, 0, 1.0 * (i + 1) / steps)
        allegro5.al_draw_bitmap(capture, 0, 0, 0)
        allegro5.al_draw_filled_rectangle(0, 0, SCREEN_W(), SCREEN_H(), fade)
        allegro5.al_flip_display()
        poll_input()
        if keypressed() then
            break
        end
    end
    allegro5.al_destroy_bitmap(capture)
end
exports.fade_out = fade_out


local function intro_screen()
    play_sample(data[INTRO_SPL + INDEX_BASE].dat, 255, 128, 1000, false)

    local t0 = allegro5.al_get_time()
    for i = 0, 51 - INDEX_BASE do
        local x = i % 8 ---@type integer
        local y = math.floor(i / 8) ---@type integer
        stretch_blit(data[INTRO_ANIM + INDEX_BASE].dat, x * 320, y * 200, 320, 200, 0, 0, SCREEN_W(), SCREEN_H())
        allegro5.al_flip_display()
        local dt = t0 + i * 0.050 - allegro5.al_get_time()
        allegro5.al_rest(dt)
    end

    rest(1000)
    fade_out(1)
end



---@param argv table<string, string>
---@return integer
local function run_demo(argv)
    local argc = #argv

    for c = 1, argc do
        if argv[c] == "-cheat" then
            cheat = true
        end

        if argv[c] == "-jumpstart" then
            jumpstart = true
        end
    end

    if not allegro_init() then
        return 1
    end

    local info = allegro5.ALLEGRO_MONITOR_INFO()
    allegro5.al_get_monitor_info(0, info)
    local w = math.floor((info.x2 - info.x1) * 0.75) ---@type integer
    local h = math.floor((info.y2 - info.y1) * 0.75) ---@type integer

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_RESIZABLE)
    a4_aux.screen = allegro5.al_create_display(w, h)
    if not a4_aux.screen then
        allegro_message("Error setting graphics mode\n")
        os.exit(1)
    end
    allegro5.al_init_image_addon()
    allegro5.al_init_acodec_addon()
    install_keyboard()
    install_mouse()
    install_timer()
    allegro5.al_init_font_addon()
    allegro5.al_init_ttf_addon()
    allegro5.al_init_primitives_addon()

    a4_aux.font = allegro5.al_create_builtin_font()

    if not install_sound() then
        allegro_message("Error initialising sound\n%s\n", a4_aux.allegro_error)
    end

    -- if install_joystick(JOY_TYPE_AUTODETECT) then
    --     allegro_message("Error initialising joystick\n%s\n", allegro_error);
    --     install_joystick(JOY_TYPE_NONE);
    -- end

    data_load()

    if not jumpstart then
        intro_screen()
    end

    local t0 = current_clock()
    generate_explosions()
    local t1 = current_clock()
    print(string.format("generate_explosions time = %g s", t1 - t0))

    while title_screen() do
        play_game()
    end

    destroy_explosions()

    stop_midi()

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end

    return 0
end
exports.run_demo = run_demo

local getters = {
    max_fps = function() return max_fps end,
    cheat = function() return cheat end,
    SCREEN_W = SCREEN_W,
    SCREEN_H = SCREEN_H,
}

local setters = {
    max_fps = function(value) max_fps = value end,
    cheat = function(value) cheat = value end,
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
