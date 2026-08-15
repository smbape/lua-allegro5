#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_font_multiline.cpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")
local nihgui = require("nihgui")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

local Dialog = nihgui.Dialog
local EventHandler = nihgui.EventHandler
local HSlider = nihgui.HSlider
local Label = nihgui.Label
local List = nihgui.List
local TextEntry = nihgui.TextEntry
local Theme = nihgui.Theme
local VSlider = nihgui.VSlider

local fmod = math.fmod
local sin = math.sin

local ffi = allegro5_lua.ffi

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
    ffi = require("ffi")
else
    ffi.cdef("typedef struct ALLEGRO_FONT ALLEGRO_FONT;")
end

--[[
 -    Example program for the Allegro library, by Peter Wang.
 -
 -    Test multi line text routines.
 --]]

local TEST_TEXT = "This is utf-8 €€€€€ multi line text output with a\nhard break,\n\ntwice even!"

--[[ Helper struct for draw_custom_multiline. --]]
ffi.cdef([[
typedef struct DRAW_CUSTOM_LINE_EXTRA {
    const ALLEGRO_FONT *font;
    float x;
    float y;
    int tick;
    float line_height;
    int flags;
} DRAW_CUSTOM_LINE_EXTRA;
]])

local DRAW_CUSTOM_LINE_EXTRA = ffi.typeof("DRAW_CUSTOM_LINE_EXTRA")


--[[ This function is the helper callback that implements the actual drawing
 - for draw_custom_multiline.
 --]]
local function draw_custom_multiline_cb(line_num, line, size, extra)
    local s    = ffi.cast("DRAW_CUSTOM_LINE_EXTRA*", extra)
    local info = allegro5.ALLEGRO_USTR_INFO()
    local c    = allegro5.al_color_hsv(fmod(360.0 * line_num / 5.0 + s.tick, 360.0),
        1.0, 1.0)
    local x    = s.x + 10 + sin(line_num + s.tick * 0.05) * 10
    local y    = s.y + (s.line_height * line_num)
    allegro5.al_draw_ustr(s.font, c, x, y, 0, allegro5.al_ref_buffer(info, line, size))
    return (line_num < 5)
end

-- Avoid luajit too many callbacks error
if allegro5 ~= allegro5_lua.allegro5 then
    ffi.cdef("typedef bool (*al_do_multiline_text_cb)(int line_num, const char *line, int size, void *extra);")
    draw_custom_multiline_cb = ffi.cast("al_do_multiline_text_cb", draw_custom_multiline_cb)
end

--[[ This is a custom mult line output function that demonstrates
 - al_do_multiline_text. --]]
local function draw_custom_multiline(font, x, y, max_width, line_height, tick, text)
    local extra = DRAW_CUSTOM_LINE_EXTRA()

    extra.font = font
    extra.x = x
    extra.y = y
    extra.line_height = line_height + allegro5.al_get_font_line_height(font)
    extra.tick = tick

    allegro5.al_do_multiline_text(font, max_width, text,
        draw_custom_multiline_cb, ffi.new("DRAW_CUSTOM_LINE_EXTRA[?]", 1, { extra }))
end

local timer
local font
local font_ttf
local font_bmp
local font_gui
local font_bin

local Prog = common.class({
    __name = "Prog",
    __destroy = function(self)
        self.d:__destroy()
        self.text_entry:__destroy()
    end,
}, EventHandler)

function Prog.__init__(self, theme, display)
    self.tick = 0

    self.d = Dialog(theme, display, 14, 20)
    self.text_label = Label("Text")
    self.width_label = Label("Width")
    self.height_label = Label("Line height")
    self.align_label = Label("Align")
    self.font_label = Label("Font")
    self.text_entry = TextEntry(TEST_TEXT)
    self.width_slider = HSlider(200, allegro5.al_get_display_width(display))
    self.height_slider = VSlider(0, 50)
    self.text_align = List(0)
    self.text_font = List(0)

    self.text_align:append_item("Left")
    self.text_align:append_item("Center")
    self.text_align:append_item("Right")

    self.text_font:append_item("Truetype")
    self.text_font:append_item("Bitmap")
    self.text_font:append_item("Builtin")

    self.d:add(self.text_label, 0, 14, 1, 1)
    self.d:add(self.text_entry, 1, 14, 12, 1)

    self.d:add(self.width_label, 0, 15, 1, 1)
    self.d:add(self.width_slider, 1, 15, 12, 1)


    self.d:add(self.align_label, 0, 17, 2, 1)
    self.d:add(self.text_align, 2, 17, 2, 3)

    self.d:add(self.font_label, 4, 17, 2, 1)
    self.d:add(self.text_font, 6, 17, 2, 3)

    self.d:add(self.height_label, 8, 17, 2, 1)
    self.d:add(self.height_slider, 10, 17, 2, 3)
end

function Prog.run(self)
    self.d:prepare()

    self.d:register_event_source(allegro5.al_get_timer_event_source(timer))
    self.d:set_event_handler(self)

    while not self.d:is_quit_requested() do
        if self.d:is_draw_requested() then
            allegro5.al_clear_to_color(allegro5.al_map_rgb(128, 128, 128))
            self:draw_text()
            self.d:draw()
            allegro5.al_flip_display()
        end

        self.d:run_step(true)
    end
end

function Prog.handle_event(self, event)
    if event.type == allegro5.ALLEGRO_EVENT_TIMER then
        self.tick = event.timer.count
        self.d:request_draw()
    end
end

function Prog.draw_text(self)
    local x, y = 10, 10
    local sx, sy = 10, 10
    local w = self.width_slider:get_cur_value()
    local h = self.height_slider:get_cur_value()
    local flags = 0
    local text = self.text_entry:get_text()

    if self.text_font:get_selected_item_text() == "Truetype" then
        font = font_ttf
    elseif self.text_font:get_selected_item_text() == "Bitmap" then
        font = font_bmp
    elseif self.text_font:get_selected_item_text() == "Builtin" then
        font = font_bin
    end

    if self.text_align:get_selected_item_text() == "Left" then
        flags = bit.bor(allegro5.ALLEGRO_ALIGN_LEFT, allegro5.ALLEGRO_ALIGN_INTEGER)
    elseif self.text_align:get_selected_item_text() == "Center" then
        flags = bit.bor(allegro5.ALLEGRO_ALIGN_CENTER, allegro5.ALLEGRO_ALIGN_INTEGER)
        x = 10 + w / 2
    elseif self.text_align:get_selected_item_text() == "Right" then
        flags = bit.bor(allegro5.ALLEGRO_ALIGN_RIGHT, allegro5.ALLEGRO_ALIGN_INTEGER)
        x     = 10 + w
    end


    --[[ Draw a red rectangle on the top with the requested width,
    - a blue rectangle around the real bounds of the text,
    - a green line for the X axis location of drawing the text
    - and the line height, and finally the text itself.
    --]]

    allegro5.al_draw_rectangle(sx, sy - 2 + 30, sx + w, sy - 1 + 30, allegro5.al_map_rgb(255, 0, 0), 0)
    allegro5.al_draw_line(x, y + 30, x, y + h + 30, allegro5.al_map_rgb(0, 255, 0), 0)
    allegro5.al_draw_multiline_text(font, allegro5.al_map_rgb_f(1, 1, 1), x, y + 30, w, h, flags, text)

    --[[ also do some custom bultiline drawing --]]
    allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1, 1, 1), w + 10, y, 0, "Custom multiline text:")
    draw_custom_multiline(font, w + 10, y + 30, w, h, self.tick, text)
end

local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro\n")
    end
    allegro5.al_init_primitives_addon()
    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()

    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    allegro5.al_init_ttf_addon()
    init_platform_specific()

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS)
    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Unable to create display\n")
    end

    --[[ Test TTF fonts and bitmap fonts. --]]
    font_ttf = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf", 24, 0)
    if not font_ttf then
        abort_example("Failed to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf\n")
    end

    font_bmp = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/font.tga", 0, 0)
    if not font_bmp then
        abort_example("Failed to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/font.tga\n")
    end

    font_bin = allegro5.al_create_builtin_font()

    font = font_ttf

    font_gui = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf", 14, 0)
    if not font_gui then
        abort_example("Failed to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf\n")
    end

    timer = allegro5.al_create_timer(1.0 / 60)
    allegro5.al_start_timer(timer)

    --[[ Don't remove these braces. --]]
    ; (function()
        local theme = Theme(font_gui)
        local prog = Prog(theme, display)
        prog:run()
        prog:__destroy()
    end)()

    allegro5.al_destroy_font(font_bmp)
    allegro5.al_destroy_font(font_ttf)
    allegro5.al_destroy_font(font_bin)
    allegro5.al_destroy_font(font_gui)
    allegro5.al_destroy_timer(timer)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
