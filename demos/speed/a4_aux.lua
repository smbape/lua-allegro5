---@class a4_aux
---@field key boolean[]
---@field joy_left boolean
---@field joy_right boolean
---@field joy_b1 boolean
---@field screen? ALLEGRO_DISPLAY
---@field font? ALLEGRO_FONT
---@field font_video? ALLEGRO_FONT
---@field allegro_error string
local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/speed/a4_aux.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")

local new_array = common.new_array
local new_table = common.new_table

local INDEX_BASE = 1 -- lua is 1-based indexed

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated
local cos = math.cos
local sin = math.sin

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local MIN = math.min
exports.MIN = MIN

local MAX = math.max
exports.MAX = MAX

---@generic Number: number
---@param x Number
---@param y Number
---@param z Number
---@return Number
---@nodiscard
function exports.CLAMP(x, y, z)
    return MAX(x, MIN(z, y))
end

exports.ABS = math.abs

---@param x number
---@return integer
function exports.SGN(x)
    if x >= 0 then
        return 1
    else
        return -1
    end
end

---@alias Mat3f [number, number, number]
---@alias Mat3x3f [Mat3f, Mat3f, Mat3f]

--[[ transformation matrix (floating point) --]]
---@class MATRIX_f
---@field v Mat3x3f scaling and rotation
---@field t Mat3f translation
---@overload fun(v? : Mat3x3f, t? : Mat3f): MATRIX_f
local MATRIX_f = common.class({
    __name = "MATRIX_f",

    ---@param self MATRIX_f
    ---@param v? [Mat3f, Mat3f, Mat3f]
    ---@param t? Mat3f
    __init__ = function(self, v, t)
        if v == nil then v = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } } end
        if t == nil then t = { 0, 0, 0 } end
        self.v = v
        self.t = t
    end
})

---@param self MATRIX_f
---@return MATRIX_f
function MATRIX_f.clone(self)
    ---@type MATRIX_f
    local clone = getmetatable(self)()

    for i = 1, 3 do
        for j = 1, 3 do
            clone.v[i][j] = self.v[i][j]
        end
    end

    for i = 1, 3 do
        clone.t[i] = self.t[i]
    end

    return clone
end

exports.MATRIX_f = MATRIX_f


--[[ global variables --]]
local key = new_table(false, allegro5.ALLEGRO_KEY_MAX) ---@type boolean[]
local joy_left = false ---@type boolean
local joy_right = false ---@type boolean
local joy_b1 = false ---@type boolean
local screen ---@type ALLEGRO_DISPLAY
local font ---@type ALLEGRO_FONT
local font_video ---@type ALLEGRO_FONT

---@class DATAFILE
---@field dat any
---@overload fun(dat? : any): DATAFILE
local DATAFILE = common.class({
    __name = "DATAFILE",

    ---@param self DATAFILE
    ---@param dat? Mat3f
    __init__ = function(self, dat)
        self.dat = dat
    end
})
exports.DATAFILE = DATAFILE

exports.RLE_SPRITE = allegro5.ALLEGRO_BITMAP
exports.BITMAP = allegro5.ALLEGRO_BITMAP
exports.RGB = allegro5.ALLEGRO_COLOR
exports.PACKFILE = allegro5.ALLEGRO_FILE

exports.allegro_init = allegro5.al_init
exports.install_keyboard = allegro5.al_install_keyboard
exports.install_mouse = allegro5.al_install_mouse
exports.printf = function(format, ...)
    io.write(string.format(format, ...))
end
exports.allegro_message = exports.printf
local allegro_error = ""
-- #define uisspace(x) ((x) == ' ' || (x) == '\n')
exports.text_length = allegro5.al_get_text_width
exports.text_height = allegro5.al_get_font_line_height
exports.itofix = allegro5.al_itofix
exports.fixtoi = allegro5.al_fixtoi
exports.fixdiv = allegro5.al_fixdiv
exports.fixsin = allegro5.al_fixsin
exports.fixcos = allegro5.al_fixcos
exports.fixsqrt = allegro5.al_fixsqrt
exports.fixmul = allegro5.al_fixmul
-- #define stricmp strcmp
exports.create_bitmap = allegro5.al_create_bitmap

exports.AL_RAND = common.rand

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/speed/a4_aux.c
--]]

--[[
 -    SPEED - by Shawn Hargreaves, 1999
 -
 -    Allegro 5 port by Peter Wang, 2010
 -
 -    The functions in this file resemble Allegro 4 functions but do not
 -    necessarily emulate the behaviour precisely.
 --]]

local _midi_stream ---@type ALLEGRO_AUDIO_STREAM?


--[[
 - Configuration files
 --]]



--[[ emulate get_config_string() --]]
---@param cfg ALLEGRO_CONFIG
---@param section string
---@param name string
---@param def string
---@return string
local function get_config_string(cfg, section, name, def)
    local v = allegro5.al_get_config_value(cfg, section, name)
    if v then return v else return def end
end
exports.get_config_string = get_config_string


--[[ emulate get_config_int() --]]
---@param cfg ALLEGRO_CONFIG
---@param section string
---@param name string
---@param def integer
---@return integer
local function get_config_int(cfg, section, name, def)
    local v = allegro5.al_get_config_value(cfg, section, name)

    if (v) then return tonumber(v, 10) else return def end
end
exports.get_config_int = get_config_int



--[[ emulate set_config_int() --]]
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
 - Input routines
 --]]


local MAX_KEYBUF = 16


-- local key = new_table(0, allegro5.ALLEGRO_KEY_MAX) ---@type integer[]

-- local joy_left = false ---@type boolean
-- local joy_right = false ---@type boolean
-- local joy_b1 = false ---@type boolean

local keybuf = new_table(0, MAX_KEYBUF) ---@type integer[]
local keybuf_len = 0 ---@type integer
local keybuf_mutex ---@type ALLEGRO_MUTEX?

local input_queue ---@type ALLEGRO_EVENT_QUEUE?



--[[ initialises the input emulation --]]
local function init_input()
    local joy ---@type ALLEGRO_JOYSTICK?

    keybuf_len = 0
    keybuf_mutex = allegro5.al_create_mutex()

    input_queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(input_queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(input_queue, allegro5.al_get_display_event_source(screen))

    if allegro5.al_get_num_joysticks() > 0 then
        joy = allegro5.al_get_joystick(0)
        if joy then
            allegro5.al_register_event_source(input_queue, allegro5.al_get_joystick_event_source())
        end
    end
end
exports.init_input = init_input

--[[ closes down the input emulation --]]
local function shutdown_input()
    allegro5.al_destroy_mutex(keybuf_mutex)
    keybuf_mutex = nil

    allegro5.al_destroy_event_queue(input_queue)
    input_queue = nil
end
exports.shutdown_input = shutdown_input



--[[ helper function to add a keypress to a buffer --]]
local function add_key(event)
    if (event.unichar == 0) or (event.unichar > 255) then
        return
    end

    allegro5.al_lock_mutex(keybuf_mutex)

    if keybuf_len < MAX_KEYBUF then
        keybuf[keybuf_len + INDEX_BASE] = bit.bor(event.unichar, bit.band(bit.lshift(event.keycode, 8), 0xff00))
        keybuf_len = keybuf_len + 1
    end

    allegro5.al_unlock_mutex(keybuf_mutex)
end



--[[ emulate poll_keyboard() and poll_joystick() combined --]]
local function poll_input()
    local event = allegro5.ALLEGRO_EVENT()

    while allegro5.al_get_next_event(input_queue, event) do
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(event.display.source)
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            key[event.keyboard.keycode] = true
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_UP then
            key[event.keyboard.keycode] = false
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            add_key(event.keyboard)
        elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_BUTTON_DOWN then
            if event.joystick.button == 0 then
                joy_b1 = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_BUTTON_UP then
            if event.joystick.button == 0 then
                joy_b1 = false
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_AXIS then
            if event.joystick.stick == 0 and event.joystick.axis == 0 then
                local pos = event.joystick.pos
                joy_left = (pos < 0.0)
                joy_right = (pos > 0.0)
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            --[[ retrace_count incremented --]]
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_EXPOSE then

        end
    end
end
exports.poll_input = poll_input



--[[ blocking version of poll_input(), also wakes on retrace_count --]]
local function poll_input_wait()
    allegro5.al_wait_for_event(input_queue, nil)
    poll_input()
end
exports.poll_input_wait = poll_input_wait



--[[ emulate keypressed() --]]
---@return boolean
local function keypressed()
    poll_input()

    return keybuf_len > 0
end
exports.keypressed = keypressed



--[[ emulate readkey(), except this version never blocks --]]
---@return integer
local function readkey()
    local c = 0 ---@type integer

    poll_input()

    allegro5.al_lock_mutex(keybuf_mutex)

    if keybuf_len > 0 then
        c = keybuf[0 + INDEX_BASE]
        keybuf_len = keybuf_len - 1

        for i = 1, keybuf_len do
            keybuf[i - 1 + INDEX_BASE] = keybuf[i + INDEX_BASE]
        end
    end

    allegro5.al_unlock_mutex(keybuf_mutex)

    return c
end
exports.readkey = readkey



--[[ emulate clear_keybuf() --]]
local function clear_keybuf()
    allegro5.al_lock_mutex(keybuf_mutex)

    keybuf_len = 0

    allegro5.al_unlock_mutex(keybuf_mutex)
end
exports.clear_keybuf = clear_keybuf



--[[
 - Graphics routines
 --]]


local MAX_POLYGON_VERTICES = 6


-- local screen
-- local font
-- local font_video



--[[ like create_bitmap() --]]
---@param w integer
---@param h integer
---@return ALLEGRO_BITMAP
local function create_memory_bitmap(w, h)
    local oldflags = allegro5.al_get_new_bitmap_flags()
    local newflags = bit.bor(bit.band(oldflags, bit.bnot(allegro5.ALLEGRO_VIDEO_BITMAP)), allegro5.ALLEGRO_MEMORY_BITMAP)
    allegro5.al_set_new_bitmap_flags(newflags)
    local bmp = allegro5.al_create_bitmap(w, h)
    allegro5.al_set_new_bitmap_flags(oldflags)
    return bmp --[[@as ALLEGRO_BITMAP --]]
end
exports.create_memory_bitmap = create_memory_bitmap


--[[ used to clone a video bitmap from a memory bitmap; no such function in A4 --]]
---@param bmp ALLEGRO_BITMAP
---@return ALLEGRO_BITMAP
local function replace_bitmap(bmp)
    local tmp = allegro5.al_clone_bitmap(bmp)
    allegro5.al_destroy_bitmap(bmp)
    return tmp --[[@as ALLEGRO_BITMAP --]]
end
exports.replace_bitmap = replace_bitmap



---@param bitmap ALLEGRO_BITMAP
---@param x1 integer
---@param y1 integer
---@param w1 integer
---@param h1 integer
---@param x2 integer
---@param y2 integer
---@param w2 integer
---@param h2 integer
local function stretch_blit(bitmap, x1, y1, w1, h1, x2, y2, w2, h2)
    allegro5.al_draw_scaled_bitmap(bitmap, x1, y1, w1, h1, x2, y2, w2, h2, 0)
end
exports.stretch_blit = stretch_blit



---@param bitmap ALLEGRO_BITMAP
---@param x1 integer
---@param y1 integer
---@param x2 integer
---@param y2 integer
---@param w integer
---@param h integer
local function blit(bitmap, x1, y1, x2, y2, w, h)
    stretch_blit(bitmap, x1, y1, w, h, x2, y2, w, h)
end
exports.blit = blit



---@param bitmap ALLEGRO_BITMAP
---@param x integer
---@param y integer
local function draw_sprite(bitmap, x, y)
    allegro5.al_draw_bitmap(bitmap, x, y, 0)
end
exports.draw_sprite = draw_sprite


---@param bitmap ALLEGRO_BITMAP
---@param x integer
---@param y integer
---@param angle integer
local function rotate_sprite(bitmap, x, y, angle)
    allegro5.al_draw_rotated_bitmap(bitmap, 0, 0, x, y, angle, 0)
end
exports.rotate_sprite = rotate_sprite



--[[ approximate solid_mode() function, but we we use alpha for transparent
 - pixels instead of a mask color
 --]]
local function solid_mode()
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
end
exports.solid_mode = solid_mode



--[[ emulate makecol() --]]
---@param r integer
---@param g integer
---@param b integer
---@return ALLEGRO_COLOR
local function makecol(r, g, b)
    return allegro5.al_map_rgb(r, g, b)
end
exports.makecol = makecol



--[[ emulate hline() --]]
---@param x1 integer
---@param y integer
---@param x2 integer
---@param c ALLEGRO_COLOR
local function hline(x1, y, x2, c)
    allegro5.al_draw_line(x1 + 0.5, y + 0.5, x2 + 0.5, y + 0.5, c, 1)
end
exports.hline = hline



--[[ emulate vline() --]]
---@param x integer
---@param y1 integer
---@param y2 integer
---@param c ALLEGRO_COLOR
local function vline(x, y1, y2, c)
    allegro5.al_draw_line(x + 0.5, y1 + 0.5, x + 0.5, y2 + 0.5, c, 1)
end
exports.vline = vline



--[[ emulate line() --]]
---@param x1 integer
---@param y1 integer
---@param x2 integer
---@param y2 integer
---@param color ALLEGRO_COLOR
local function line(x1, y1, x2, y2, color)
    allegro5.al_draw_line(x1 + 0.5, y1 + 0.5, x2 + 0.5, y2 + 0.5, color, 1)
end
exports.line = line



--[[ emulate rectfill() --]]
---@param x1 integer
---@param y1 integer
---@param x2 integer
---@param y2 integer
---@param color ALLEGRO_COLOR
local function rectfill(x1, y1, x2, y2, color)
    allegro5.al_draw_filled_rectangle(x1, y1, x2 + 1, y2 + 1, color)
end
exports.rectfill = rectfill



--[[ emulate circle() --]]
---@param x integer
---@param y integer
---@param radius integer
---@param color ALLEGRO_COLOR
local function circle(x, y, radius, color)
    allegro5.al_draw_circle(x + 0.5, y + 0.5, radius, color, 1)
end
exports.circle = circle



--[[ emulate circlefill() --]]
---@param x integer
---@param y integer
---@param radius integer
---@param color ALLEGRO_COLOR
local function circlefill(x, y, radius, color)
    allegro5.al_draw_filled_circle(x + 0.5, y + 0.5, radius, color)
end
exports.circlefill = circlefill



--[[ emulate stretch_sprite() --]]
---@param bmp ALLEGRO_BITMAP
---@param sprite ALLEGRO_BITMAP
---@param x integer
---@param y integer
---@param w integer
---@param h integer
local function stretch_sprite(bmp, sprite, x, y, w, h)
    local state = allegro5.ALLEGRO_STATE()

    allegro5.al_store_state(state, allegro5.ALLEGRO_STATE_TARGET_BITMAP)

    allegro5.al_set_target_bitmap(bmp)
    allegro5.al_draw_scaled_bitmap(sprite,
        0, 0, allegro5.al_get_bitmap_width(sprite), allegro5.al_get_bitmap_height(sprite),
        x, y, w, h, 0)

    allegro5.al_restore_state(state)
end
exports.stretch_sprite = stretch_sprite



--[[ emulate polygon() for convex polygons only --]]
---@param vertices integer
---@param points integer[]
---@param color ALLEGRO_COLOR
local function polygon(vertices, points, color)
    local vtxs, vtxs_ptr = new_array("ALLEGRO_VERTEX", MAX_POLYGON_VERTICES + 2) ---@type { [integer]: ALLEGRO_VERTEX }, any

    assert(vertices <= MAX_POLYGON_VERTICES)

    vtxs[0].x = 0.0
    vtxs[0].y = 0.0
    vtxs[0].z = 0.0
    vtxs[0].color = color
    vtxs[0].u = 0
    vtxs[0].v = 0

    for i = 0, vertices - INDEX_BASE do
        vtxs[0].x = vtxs[0].x + (points[i * 2 + INDEX_BASE])
        vtxs[0].y = vtxs[0].y + (points[i * 2 + 1 + INDEX_BASE])
    end

    vtxs[0].x = vtxs[0].x / (vertices)
    vtxs[0].y = vtxs[0].y / (vertices)

    for i = 1, vertices do
        vtxs[i].x = points[(i - 1) * 2 + INDEX_BASE]
        vtxs[i].y = points[(i - 1) * 2 + 1 + INDEX_BASE]
        vtxs[i].z = 0.0
        vtxs[i].color = color
        vtxs[i].u = 0
        vtxs[i].v = 0
    end

    vtxs[vertices + 1] = vtxs[1]

    allegro5.al_draw_prim(vtxs_ptr, nil, nil, 0, vertices + 2, allegro5.ALLEGRO_PRIM_TRIANGLE_FAN)
end
exports.polygon = polygon



--[[ emulate textout() --]]
---@param f ALLEGRO_FONT
---@param s string
---@param x integer
---@param y integer
---@param c ALLEGRO_COLOR
local function textout(f, s, x, y, c)
    allegro5.al_draw_text(f, c, x, y, allegro5.ALLEGRO_ALIGN_LEFT, s)
end
exports.textout = textout



--[[ emulate textout_centre() --]]
---@param f ALLEGRO_FONT
---@param s string
---@param x integer
---@param y integer
---@param c ALLEGRO_COLOR
local function textout_centre(f, s, x, y, c)
    allegro5.al_draw_text(f, c, x, y, allegro5.ALLEGRO_ALIGN_CENTRE, s)
end
exports.textout_centre = textout_centre



--[[ emulate textprintf() --]]
---@param f ALLEGRO_FONT
---@param x integer
---@param y integer
---@param color ALLEGRO_COLOR
---@param fmt string
---@param ... any
local function textprintf(f, x, y, color, fmt, ...)
    local buf = string.format(fmt, ...)
    textout(f, buf, x, y, color)
end
exports.textprintf = textprintf



--[[
 - Matrix routines
 --]]


---@return MATRIX_f
local identity_matrix_f = function()
    local m = MATRIX_f(unpack({
        {
            --[[ 3x3 identity --]]
            { 1.0, 0.0, 0.0 },
            { 0.0, 1.0, 0.0 },
            { 0.0, 0.0, 1.0 },
        },

        --[[ zero translation --]]
        { 0.0, 0.0, 0.0 }
    }))

    return m --[[@as MATRIX_f]]
end



--[[ get_scaling_matrix_f:
 -  Floating point version of get_scaling_matrix().
 --]]
---@param x number
---@param y number
---@param z number
---@return MATRIX_f m
local function get_scaling_matrix_f(x, y, z)
    local m = identity_matrix_f()

    m.v[0 + INDEX_BASE][0 + INDEX_BASE] = x
    m.v[1 + INDEX_BASE][1 + INDEX_BASE] = y
    m.v[2 + INDEX_BASE][2 + INDEX_BASE] = z

    return m
end
exports.get_scaling_matrix_f = get_scaling_matrix_f



--[[ get_z_rotate_matrix_f:
 -  Floating point version of get_z_rotate_matrix().
 --]]
---@param r number
---@return MATRIX_f m
local function get_z_rotate_matrix_f(r)
    local s = sin(r * allegro5.ALLEGRO_PI / 128.0)
    local c = cos(r * allegro5.ALLEGRO_PI / 128.0)
    local m = identity_matrix_f()

    m.v[0 + INDEX_BASE][0 + INDEX_BASE] = c
    m.v[0 + INDEX_BASE][1 + INDEX_BASE] = -s

    m.v[1 + INDEX_BASE][0 + INDEX_BASE] = s
    m.v[1 + INDEX_BASE][1 + INDEX_BASE] = c

    return m
end
exports.get_z_rotate_matrix_f = get_z_rotate_matrix_f



--[[ qtranslate_matrix_f:
 -  Floating point version of qtranslate_matrix().
 --]]
---@param m MATRIX_f
---@param x number
---@param y number
---@param z number
local function qtranslate_matrix_f(m, x, y, z)
    m.t[0 + INDEX_BASE] = m.t[0 + INDEX_BASE] + (x)
    m.t[1 + INDEX_BASE] = m.t[1 + INDEX_BASE] + (y)
    m.t[2 + INDEX_BASE] = m.t[2 + INDEX_BASE] + (z)
end
exports.qtranslate_matrix_f = qtranslate_matrix_f



--[[ matrix_mul_f:
 -  Floating point version of matrix_mul().
 --]]
---@param m1 MATRIX_f
---@param m2 MATRIX_f
---@param out MATRIX_f
local function matrix_mul_f(m1, m2, out)
    if m1 == out then
        m1 = m1:clone() ---@type MATRIX_f
    elseif m2 == out then
        m2 = m2:clone()
    end

    for i = 1, 3 do
        for j = 1, 3 do
            out.v[i][j] =   (m1.v[0 + INDEX_BASE][j] * m2.v[i][0 + INDEX_BASE]) +
                            (m1.v[1 + INDEX_BASE][j] * m2.v[i][1 + INDEX_BASE]) +
                            (m1.v[2 + INDEX_BASE][j] * m2.v[i][2 + INDEX_BASE])
        end

        out.t[i] =  (m1.t[0 + INDEX_BASE] * m2.v[i][0 + INDEX_BASE]) +
                    (m1.t[1 + INDEX_BASE] * m2.v[i][1 + INDEX_BASE]) +
                    (m1.t[2 + INDEX_BASE] * m2.v[i][2 + INDEX_BASE]) +
            m2.t[i]
    end
end
exports.matrix_mul_f = matrix_mul_f


---@param m MATRIX_f
---@param x number
---@param y number
---@param z number
---@param n integer
---@return number
local function CALC_ROW(m, x, y, z, n)
    return x * m.v[n + INDEX_BASE][0 + INDEX_BASE] + y * m.v[n + INDEX_BASE][1 + INDEX_BASE] +
        z * m.v[n + INDEX_BASE][2 + INDEX_BASE] + m.t[n + INDEX_BASE]
end

--[[ apply_matrix_f:
 -  Floating point vector by matrix multiplication routine.
 --]]
---@param m MATRIX_f
---@param x number
---@param y number
---@param z number
---@return number xout
---@return number yout
---@return number zout
local function apply_matrix_f(m, x, y, z)
    local xout = CALC_ROW(m, x, y, z, 0)
    local yout = CALC_ROW(m, x, y, z, 1)
    local zout = CALC_ROW(m, x, y, z, 2)

    return xout, yout, zout
end
exports.apply_matrix_f = apply_matrix_f



--[[
 - Timing routines
 --]]


local retrace_counter = nil ---@type ALLEGRO_TIMER?



--[[ start incrementing retrace_count --]]
local function start_retrace_count()
    retrace_counter = allegro5.al_create_timer(1 / 70.0)
    allegro5.al_register_event_source(input_queue, allegro5.al_get_timer_event_source(retrace_counter))
    allegro5.al_start_timer(retrace_counter)
end
exports.start_retrace_count = start_retrace_count



--[[ stop incrementing retrace_count --]]
local function stop_retrace_count()
    allegro5.al_destroy_timer(retrace_counter)
    retrace_counter = nil
end
exports.stop_retrace_count = stop_retrace_count



--[[ emulate 'retrace_count' variable --]]
---@return integer
local function retrace_count()
    ---@diagnostic disable-next-line: return-type-mismatch
    return tonumber(allegro5.al_get_timer_count(retrace_counter))
end
exports.retrace_count = retrace_count



--[[ emulate rest() --]]
---@param time integer
local function rest(time)
    allegro5.al_rest(0.001 * time)
end
exports.rest = rest



local function install_timer()
    init_input()
    start_retrace_count()
end
exports.install_timer = install_timer



--[[
 - Sound routines
 --]]



--[[ emulate create_sample(), for unsigned 8-bit mono samples --]]
---@param freq integer
---@param len integer
---@return ALLEGRO_SAMPLE?
local function create_sample_u8(freq, len)
    local buf = allegro5.al_malloc(freq * len)

    return allegro5.al_create_sample(buf, len, freq, allegro5.ALLEGRO_AUDIO_DEPTH_UINT8,
        allegro5.ALLEGRO_CHANNEL_CONF_1, true)
end
exports.create_sample_u8 = create_sample_u8



--[[ emulate play_sample() --]]
---@param spl ALLEGRO_SAMPLE?
---@param vol integer
---@param pan integer
---@param freq integer
---@param loop boolean
local function play_sample(spl, vol, pan, freq, loop)
    if spl == nil then
        return
    end

    local playmode = (function()
        if loop then
            return allegro5.ALLEGRO_PLAYMODE_LOOP
        else
            return allegro5.ALLEGRO_PLAYMODE_ONCE
        end
    end)()

    allegro5.al_play_sample(spl, vol / 255.0, (pan - 128) / 128.0, freq / 1000.0,
        playmode, nil)
end
exports.play_sample = play_sample



---@return boolean
local function install_sound()
    if not allegro5.al_install_audio() then
        return false
    end
    allegro5.al_reserve_samples(100)
    return true
end
exports.install_sound = install_sound



local function stop_midi()
    if _midi_stream then
        allegro5.al_destroy_audio_stream(_midi_stream)
        _midi_stream = nil
    end
end
exports.stop_midi = stop_midi



---@param midi string
---@param loop boolean
local function play_midi(midi, loop)
    stop_midi()
    _midi_stream = allegro5.al_load_audio_stream(midi, 2, 4096)
    if not _midi_stream then
        exports.printf("Couldn't load %s\n", midi)
    end
    allegro5.al_attach_audio_stream_to_mixer(_midi_stream, allegro5.al_get_default_mixer())
    if loop then
        allegro5.al_set_audio_stream_playmode(_midi_stream, allegro5.ALLEGRO_PLAYMODE_LOOP)
    end
end
exports.play_midi = play_midi



local getters = {
    key = function() return key end,
    joy_left = function() return joy_left end,
    joy_right = function() return joy_right end,
    joy_b1 = function() return joy_b1 end,
    screen = function() return screen end,
    font = function() return font end,
    font_video = function() return font_video end,
    allegro_error = function() return allegro_error end,
}

local setters = {
    key = function(value) key = value end,
    joy_left = function(value) joy_left = value end,
    joy_right = function(value) joy_right = value end,
    joy_b1 = function(value) joy_b1 = value end,
    screen = function(value) screen = value end,
    font = function(value) font = value end,
    font_video = function(value) font_video = value end,
    allegro_error = function(value) allegro_error = value end,
}

setmetatable(exports, {
    __index = function(self, key_)
        local getter = getters[key_]
        if type(getter) == "function" then
            return getter()
        end
        return nil
    end,
    __newindex = function(self, key_, value)
        local setter = setters[key_]
        if type(setter) == "function" then
            setter(value)
        else
            rawset(self, key_, value)
        end
    end
})

return exports
