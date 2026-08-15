#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_color.cpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")
local nihgui = require("nihgui")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local new_array = common.new_array
local new_table = common.new_table

local Dialog = nihgui.Dialog
local Label = nihgui.Label
local List = nihgui.List
local Theme = nihgui.Theme
local VSlider = nihgui.VSlider

local INDEX_BASE = 1 -- lua is 1-based indexed

local c_string = allegro5_lua.std.string

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    c_string = ffi.string
end

--[[
 -    Example program for the Allegro library, by Elias Pschernig.
 -
 -    Demonstrates some of the conversion functions in the color addon.
 --]]

local SLIDERS_COUNT = 19
local names = { "R", "G", "B", "H", "S", "V", "H", "S", "L",
    "Y", "U", "V", "C", "M", "Y", "K", "L", "C", "H" }

local function clamp(x)
    if x < 0 then
        return 0
    end
    if x > 1 then
        return 1
    end
    return x
end

local Prog = common.class({
    __name = "Prog",
    __destroy = function(self)
        self.d:__destroy()
    end,
})

function Prog.__init__(self, theme, display)
    self.sliders = new_table(VSlider, SLIDERS_COUNT)
    self.labels = new_table(Label, SLIDERS_COUNT)
    self.labels2 = new_table(Label, SLIDERS_COUNT)
    self.previous = {}

    self.d = Dialog(theme, display, 640, 480)
    for i = 0, SLIDERS_COUNT - INDEX_BASE do
        local j = (function() if i < 12 then return math.floor(i / 3) elseif i < 16 then return 4 else return 5 end end)()
        self.sliders[i + INDEX_BASE] = VSlider(1000, 1000)
        self.d:add(self.sliders[i + INDEX_BASE], 8 + i * 32 + j * 16, 8, 15, 256)
        self.labels[i + INDEX_BASE]:set_text(names[i + INDEX_BASE])
        self.d:add(self.labels[i + INDEX_BASE], i * 32 + j * 16, 8 + 256, 32, 20)
        self.d:add(self.labels2[i + INDEX_BASE], i * 32 + j * 16, 8 + 276, 32, 20)
        self.previous[i + INDEX_BASE] = 0
    end
end

function Prog.run(self)
    self.d:prepare()

    while not self.d:is_quit_requested() do
        if self.d:is_draw_requested() then
            allegro5.al_clear_to_color(allegro5.al_map_rgb(128, 128, 128))
            local v = {}
            local keep = -1
            for i = 0, SLIDERS_COUNT - INDEX_BASE do
                local x = self.sliders[i + INDEX_BASE]:get_cur_value()
                v[i + INDEX_BASE] = x / 1000.0
                if self.previous[i + INDEX_BASE] ~= x then
                    keep = i
                end
            end

            if keep ~= -1 then
                local space = (function() if keep < 12 then return math.floor(keep / 3) elseif keep < 16 then return 4 else return 5 end end)()

                if space == 0 then
                    v[3 + INDEX_BASE], v[4 + INDEX_BASE], v[5 + INDEX_BASE] = allegro5.al_color_rgb_to_hsv(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[6 + INDEX_BASE], v[7 + INDEX_BASE], v[8 + INDEX_BASE] = allegro5.al_color_rgb_to_hsl(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[9 + INDEX_BASE], v[10 + INDEX_BASE], v[11 + INDEX_BASE] = allegro5.al_color_rgb_to_yuv(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[12 + INDEX_BASE], v[13 + INDEX_BASE], v[14 + INDEX_BASE], v[15 + INDEX_BASE] = allegro5.al_color_rgb_to_cmyk(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[16 + INDEX_BASE], v[17 + INDEX_BASE], v[18 + INDEX_BASE] = allegro5.al_color_rgb_to_lch(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[3 + INDEX_BASE] = v[3 + INDEX_BASE] / (360)
                    v[6 + INDEX_BASE] = v[6 + INDEX_BASE] / (360)
                    v[18 + INDEX_BASE] = v[18 + INDEX_BASE] / (allegro5.ALLEGRO_PI * 2)
                elseif space == 1 then
                    v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE] = allegro5.al_color_hsv_to_rgb(v[3 + INDEX_BASE] * 360, v[4 + INDEX_BASE], v[5 + INDEX_BASE])
                    v[6 + INDEX_BASE], v[7 + INDEX_BASE], v[8 + INDEX_BASE] = allegro5.al_color_rgb_to_hsl(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[9 + INDEX_BASE], v[10 + INDEX_BASE], v[11 + INDEX_BASE] = allegro5.al_color_rgb_to_yuv(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[12 + INDEX_BASE], v[13 + INDEX_BASE], v[14 + INDEX_BASE], v[15 + INDEX_BASE] = allegro5.al_color_rgb_to_cmyk(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[16 + INDEX_BASE], v[17 + INDEX_BASE], v[18 + INDEX_BASE] = allegro5.al_color_rgb_to_lch(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[6 + INDEX_BASE] = v[6 + INDEX_BASE] / (360)
                    v[18 + INDEX_BASE] = v[18 + INDEX_BASE] / (allegro5.ALLEGRO_PI * 2)
                elseif space == 2 then
                    v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE] = allegro5.al_color_hsl_to_rgb(v[6 + INDEX_BASE] * 360, v[7 + INDEX_BASE], v[8 + INDEX_BASE])
                    v[3 + INDEX_BASE], v[4 + INDEX_BASE], v[5 + INDEX_BASE] = allegro5.al_color_rgb_to_hsv(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[9 + INDEX_BASE], v[10 + INDEX_BASE], v[11 + INDEX_BASE] = allegro5.al_color_rgb_to_yuv(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[12 + INDEX_BASE], v[13 + INDEX_BASE], v[14 + INDEX_BASE], v[15 + INDEX_BASE] = allegro5.al_color_rgb_to_cmyk(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[16 + INDEX_BASE], v[17 + INDEX_BASE], v[18 + INDEX_BASE] = allegro5.al_color_rgb_to_lch(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[3 + INDEX_BASE] = v[3 + INDEX_BASE] / (360)
                    v[18 + INDEX_BASE] = v[18 + INDEX_BASE] / (allegro5.ALLEGRO_PI * 2)
                elseif space == 3 then
                    v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE] = allegro5.al_color_yuv_to_rgb(v[9 + INDEX_BASE], v[10 + INDEX_BASE], v[11 + INDEX_BASE])
                    v[0 + INDEX_BASE] = clamp(v[0 + INDEX_BASE])
                    v[1 + INDEX_BASE] = clamp(v[1 + INDEX_BASE])
                    v[2 + INDEX_BASE] = clamp(v[2 + INDEX_BASE])
                    v[9 + INDEX_BASE], v[10 + INDEX_BASE], v[11 + INDEX_BASE] = allegro5.al_color_rgb_to_yuv(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[3 + INDEX_BASE], v[4 + INDEX_BASE], v[5 + INDEX_BASE] = allegro5.al_color_rgb_to_hsv(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[6 + INDEX_BASE], v[7 + INDEX_BASE], v[8 + INDEX_BASE] = allegro5.al_color_rgb_to_hsl(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[12 + INDEX_BASE], v[13 + INDEX_BASE], v[14 + INDEX_BASE], v[15 + INDEX_BASE] = allegro5.al_color_rgb_to_cmyk(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[16 + INDEX_BASE], v[17 + INDEX_BASE], v[18 + INDEX_BASE] = allegro5.al_color_rgb_to_lch(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[3 + INDEX_BASE] = v[3 + INDEX_BASE] / (360)
                    v[6 + INDEX_BASE] = v[6 + INDEX_BASE] / (360)
                    v[18 + INDEX_BASE] = v[18 + INDEX_BASE] / (allegro5.ALLEGRO_PI * 2)
                elseif space == 4 then
                    v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE] = allegro5.al_color_cmyk_to_rgb(v[12 + INDEX_BASE], v[13 + INDEX_BASE], v[14 + INDEX_BASE], v[15 + INDEX_BASE])
                    v[3 + INDEX_BASE], v[4 + INDEX_BASE], v[5 + INDEX_BASE] = allegro5.al_color_rgb_to_hsv(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[6 + INDEX_BASE], v[7 + INDEX_BASE], v[8 + INDEX_BASE] = allegro5.al_color_rgb_to_hsl(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[9 + INDEX_BASE], v[10 + INDEX_BASE], v[11 + INDEX_BASE] = allegro5.al_color_rgb_to_yuv(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[16 + INDEX_BASE], v[17 + INDEX_BASE], v[18 + INDEX_BASE] = allegro5.al_color_rgb_to_lch(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[3 + INDEX_BASE] = v[3 + INDEX_BASE] / (360)
                    v[6 + INDEX_BASE] = v[6 + INDEX_BASE] / (360)
                    v[18 + INDEX_BASE] = v[18 + INDEX_BASE] / (allegro5.ALLEGRO_PI * 2)
                elseif space == 5 then
                    v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE] = allegro5.al_color_lch_to_rgb(v[16 + INDEX_BASE], v[17 + INDEX_BASE], v[18 + INDEX_BASE] * 2 * allegro5.ALLEGRO_PI)
                    v[0 + INDEX_BASE] = clamp(v[0 + INDEX_BASE])
                    v[1 + INDEX_BASE] = clamp(v[1 + INDEX_BASE])
                    v[2 + INDEX_BASE] = clamp(v[2 + INDEX_BASE])
                    v[3 + INDEX_BASE], v[4 + INDEX_BASE], v[5 + INDEX_BASE] = allegro5.al_color_rgb_to_hsv(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[6 + INDEX_BASE], v[7 + INDEX_BASE], v[8 + INDEX_BASE] = allegro5.al_color_rgb_to_hsl(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[9 + INDEX_BASE], v[10 + INDEX_BASE], v[11 + INDEX_BASE] = allegro5.al_color_rgb_to_yuv(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[12 + INDEX_BASE], v[13 + INDEX_BASE], v[14 + INDEX_BASE], v[15 + INDEX_BASE] = allegro5.al_color_rgb_to_cmyk(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[16 + INDEX_BASE], v[17 + INDEX_BASE], v[18 + INDEX_BASE] = allegro5.al_color_rgb_to_lch(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
                    v[3 + INDEX_BASE] = v[3 + INDEX_BASE] / (360)
                    v[6 + INDEX_BASE] = v[6 + INDEX_BASE] / (360)
                    v[18 + INDEX_BASE] = v[18 + INDEX_BASE] / (allegro5.ALLEGRO_PI * 2)
                end
            end

            for i = 0, SLIDERS_COUNT - INDEX_BASE do
                self.sliders[i + INDEX_BASE]:set_cur_value(math.floor(v[i + INDEX_BASE] * 1000))
                self.previous[i + INDEX_BASE] = self.sliders[i + INDEX_BASE]:get_cur_value()
                local c = tostring(math.floor(v[i + INDEX_BASE] * 100))
                self.labels2[i + INDEX_BASE]:set_text(c)
            end

            self.d:draw()

            local target = allegro5.al_get_target_bitmap()
            local w = allegro5.al_get_bitmap_width(target)
            local h = allegro5.al_get_bitmap_height(target)
            self:draw_swatch(0, h - 80, w, h, v)

            allegro5.al_flip_display()
        end

        self.d:run_step(true)
    end
end

function Prog.draw_swatch(self, x1, y1, x2, y2, v)
    allegro5.al_draw_filled_rectangle(x1, y1, x2, y2,
        allegro5.al_map_rgb_f(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE]))

    local name = allegro5.al_color_rgb_to_name(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE])
    local _, html = new_array("char", 8)
    allegro5.al_color_rgb_to_html(v[0 + INDEX_BASE], v[1 + INDEX_BASE], v[2 + INDEX_BASE], html)
    allegro5.al_draw_text(self.d:get_theme().font, allegro5.al_map_rgb(0, 0, 0), x1, y1 - 20, 0, name)
    allegro5.al_draw_text(self.d:get_theme().font, allegro5.al_map_rgb(0, 0, 0), x1, y1 - 40, 0, c_string(html))
end

local function main()
    local display
    local font

    if not allegro5.al_init() then
        abort_example("Could not init Allegro\n")
    end
    allegro5.al_init_primitives_addon()
    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()

    allegro5.al_init_font_addon()
    allegro5.al_init_ttf_addon()
    init_platform_specific()

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS)
    display = allegro5.al_create_display(720, 480)
    if not display then
        abort_example("Unable to create display\n")
    end
    font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf", 12, 0)
    if not font then
        abort_example("Failed to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf\n")
    end

    --[[ Prog is destroyed at the end of this scope. --]]
    ; (function()
        local theme = Theme(font)
        local prog = Prog(theme, display)
        prog:run()
        prog:__destroy()
    end)()

    allegro5.al_destroy_font(font)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
