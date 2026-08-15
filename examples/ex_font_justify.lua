#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_font_justify.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")
local nihgui = require("nihgui")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

local Dialog = nihgui.Dialog
local HSlider = nihgui.HSlider
local Label = nihgui.Label
local TextEntry = nihgui.TextEntry
local Theme = nihgui.Theme

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 -    Example program for the Allegro library, by Peter Wang.
 -
 -    Test text justification routines.
 --]]

local font
local font_gui

local Prog = common.class({
    __name = "Prog",
    __destroy = function(self)
        self.d:__destroy()
        self.text_entry:__destroy()
    end,
})

function Prog.__init__(self, theme, display)
    self.d = Dialog(theme, display, 10, 20)
    self.text_label = Label("Text")
    self.width_label = Label("Width")
    self.diff_label = Label("Diff")
    self.text_entry = TextEntry("Lorem ipsum dolor sit amet")
    self.width_slider = HSlider(400, allegro5.al_get_display_width(display))
    self.diff_slider = HSlider(100, allegro5.al_get_display_width(display))

    self.d:add(self.text_label, 0, 10, 1, 1)
    self.d:add(self.text_entry, 1, 10, 8, 1)

    self.d:add(self.width_label, 0, 12, 1, 1)
    self.d:add(self.width_slider, 1, 12, 8, 1)

    self.d:add(self.diff_label, 0, 14, 1, 1)
    self.d:add(self.diff_slider, 1, 14, 8, 1)
end

function Prog.run(self)
    self.d:prepare()

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

function Prog.draw_text(self)
    local target = allegro5.al_get_target_bitmap()
    local cx = math.floor(allegro5.al_get_bitmap_width(target) / 2)
    local x1 = cx - math.floor(self.width_slider:get_cur_value() / 2)
    local x2 = cx + math.floor(self.width_slider:get_cur_value() / 2)
    local diff = self.diff_slider:get_cur_value()
    local th = allegro5.al_get_font_line_height(font)

    allegro5.al_draw_justified_text(font, allegro5.al_map_rgb_f(1, 1, 1), x1, x2, 50, diff,
        allegro5.ALLEGRO_ALIGN_INTEGER, self.text_entry:get_text())

    allegro5.al_draw_rectangle(x1, 50, x2, 50 + th, allegro5.al_map_rgb(0, 0, 255), 0)

    allegro5.al_draw_line(cx - math.floor(diff / 2), 53 + th, cx + math.floor(diff / 2), 53 + th,
        allegro5.al_map_rgb(0, 255, 0), 0)
end

local function main(argv)
    local argc = #argv

    local test_ttf = true
    for i = 1, argc do
        if argv[i] == "--ttf" then
            test_ttf = true
        elseif argv[i] == "--no-ttf" then
            test_ttf = false
        end
    end

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

    --[[ Test TTF fonts or bitmap fonts. --]]
    if test_ttf then
        font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf", 24, 0)
        if not font then
            abort_example("Failed to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf\n")
        end
    else
        font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/font.tga", 0, 0)
        if not font then
            abort_example("Failed to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/font.tga\n")
        end
    end

    font_gui = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf", 14, 0)
    if not font_gui then
        abort_example("Failed to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf\n")
    end

    --[[ Don't remove these braces. --]]
    ; (function()
        local theme = Theme(font_gui)
        local prog = Prog(theme, display)
        prog:run()
        prog:__destroy()
    end)()

    allegro5.al_destroy_font(font)
    allegro5.al_destroy_font(font_gui)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
