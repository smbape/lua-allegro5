#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_pixelformat.cpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")
local nihgui = require("nihgui")

local env = common.env

local abort_example = common.abort_example
local open_log = common.open_log
local init_platform_specific = common.init_platform_specific
local close_log = common.close_log
local log_printf = common.log_printf
local new_table = common.new_table

local Dialog = nihgui.Dialog
local Label = nihgui.Label
local List = nihgui.List
local Theme = nihgui.Theme
local ToggleButton = nihgui.ToggleButton

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 -    Simple (incomplete) test of pixel format conversions.
 -
 -    This should be made comprehensive.
 --]]

local function FORMAT(format, name)
    return {
        format = format,
        name = name,
    }
end

local formats = new_table(FORMAT, {
    { allegro5.ALLEGRO_PIXEL_FORMAT_ANY,                  "any" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_ANY_NO_ALPHA,         "no alpha" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_ANY_WITH_ALPHA,       "alpha" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_ANY_15_NO_ALPHA,      "15" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_ANY_16_NO_ALPHA,      "16" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_ANY_16_WITH_ALPHA,    "16 alpha" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_ANY_24_NO_ALPHA,      "24" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_ANY_32_NO_ALPHA,      "32" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_ANY_32_WITH_ALPHA,    "32 alpha" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_ARGB_8888,            "ARGB8888" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_RGBA_8888,            "RGBA8888" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_ARGB_4444,            "ARGB4444" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_RGB_888,              "RGB888" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_RGB_565,              "RGB565" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_RGB_555,              "RGB555" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_RGBA_5551,            "RGBA5551" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_ARGB_1555,            "ARGB1555" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_8888,            "ABGR8888" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_XBGR_8888,            "XBGR8888" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_BGR_888,              "BGR888" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_BGR_565,              "BGR565" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_BGR_555,              "BGR555" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_RGBX_8888,            "RGBX8888" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_XRGB_8888,            "XRGB8888" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_F32,             "ABGR32F" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_8888_LE,         "ABGR(LE)" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_RGBA_4444,            "RGBA4444" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_SINGLE_CHANNEL_8,     "SINGLE_CHANNEL_8" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_COMPRESSED_RGBA_DXT1, "RGBA_DXT1" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_COMPRESSED_RGBA_DXT3, "RGBA_DXT3" },
    { allegro5.ALLEGRO_PIXEL_FORMAT_COMPRESSED_RGBA_DXT5, "RGBA_DXT5" },
})

local NUM_FORMATS = #formats


local function get_format_name(bmp)
    if not bmp then
        return "none"
    end

    local format = allegro5.al_get_bitmap_format(bmp)
    for i = 1, NUM_FORMATS do
        if formats[i].format == format then
            return formats[i].name
        end
    end
    return "unknown"
end


local Prog = common.class({
    __name = "Prog",
    __destroy = function(self)
        self.d:__destroy()
    end,
})


function Prog.__init__(self, theme, display, bmp_filename)
    self.d = Dialog(theme, display, 20, 30)
    self.source_label = Label("Source")
    self.dest_label = Label("Destination")
    self.source_list = List()
    self.dest_list = List()
    self.true_formats = Label("")
    self.use_memory_button = ToggleButton("Use memory bitmaps")
    self.enable_timing_button = ToggleButton("Enable timing")
    self.time_label = Label("")
    self.bmp_filename = bmp_filename
    self.d:add(self.source_label, 11, 0, 4, 1)
    self.d:add(self.source_list, 11, 1, 4, 27)
    self.d:add(self.dest_label, 15, 0, 4, 1)
    self.d:add(self.dest_list, 15, 1, 4, 27)
    self.d:add(self.true_formats, 0, 20, 10, 1)
    self.d:add(self.use_memory_button, 0, 24, 10, 2)
    self.d:add(self.enable_timing_button, 0, 26, 10, 2)
    self.d:add(self.time_label, 0, 22, 10, 1)

    for i = 1, NUM_FORMATS do
        self.source_list:append_item(formats[i].name)
        self.dest_list:append_item(formats[i].name)
    end
end

function Prog.run(self)
    self.d:prepare()

    while not self.d:is_quit_requested() do
        if self.d:is_draw_requested() then
            allegro5.al_clear_to_color(allegro5.al_map_rgb(128, 128, 128))
            self:draw_sample()
            self.d:draw()
            allegro5.al_flip_display()
        end

        self.d:run_step(true)
    end
end


function Prog.draw_sample(self)
    local i = self.source_list:get_cur_value()
    local j = self.dest_list:get_cur_value()
    local use_memory = self.use_memory_button:get_pushed()
    local enable_timing = self.enable_timing_button:get_pushed()
    local bmp_w = 128
    local bmp_h = 128

    if use_memory then
        allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    else
        allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_VIDEO_BITMAP)
    end

    allegro5.al_set_new_bitmap_format(formats[i + INDEX_BASE].format)

    local bitmap1 = allegro5.al_load_bitmap(self.bmp_filename)
    if not bitmap1 then
        log_printf("Could not load image %s, bitmap format = %d\n", self.bmp_filename,
            formats[i + INDEX_BASE].format)
    else
        bmp_w = allegro5.al_get_bitmap_width(bitmap1)
        bmp_h = allegro5.al_get_bitmap_height(bitmap1)
    end

    allegro5.al_set_new_bitmap_format(formats[j + INDEX_BASE].format)

    local bitmap2 = allegro5.al_create_bitmap(bmp_w, bmp_h)
    if not bitmap2 then
        log_printf("Could not create bitmap, format = %d\n", formats[j + INDEX_BASE].format)
    end

    if bitmap1 and bitmap2 then
        local target = allegro5.al_get_target_bitmap()

        allegro5.al_set_target_bitmap(bitmap2)
        allegro5.al_clear_to_color(allegro5.al_map_rgb(128, 128, 128))
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
        if enable_timing then
            local t0, t1 = 0, 0
            local frames = 0

            t0 = allegro5.al_get_time()
            log_printf("Timing...\n")
            repeat
                allegro5.al_draw_bitmap(bitmap1, 0, 0, 0)
                frames = frames + 1
                t1 = allegro5.al_get_time()
            until not (t1 - t0 < 0.25)
            log_printf("    ...done.\n")
            local str = string.format("%.0f FPS", frames / (t1 - t0))
            self.time_label:set_text(str)
        else
            allegro5.al_draw_bitmap(bitmap1, 0, 0, 0)
            self.time_label:set_text("")
        end

        allegro5.al_set_target_bitmap(target)
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
        allegro5.al_draw_bitmap(bitmap2, 0, 0, 0)
    else
        allegro5.al_draw_line(0, 0, 320, 200, allegro5.al_map_rgb_f(1, 0, 0), 0)
        allegro5.al_draw_line(0, 200, 320, 0, allegro5.al_map_rgb_f(1, 0, 0), 0)
    end

    local s = get_format_name(bitmap1)
    s = s .. " -> "
    s = s .. get_format_name(bitmap2)
    self.true_formats:set_text(s)

    allegro5.al_destroy_bitmap(bitmap1)
    allegro5.al_destroy_bitmap(bitmap2)
end

local function main(argv)
    local argc = #argv

    local bmp_filename = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/allegro.pcx"

    if argc >= 1 then
        bmp_filename = argv[1]
    end

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    allegro5.al_init_primitives_addon()
    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    init_platform_specific()

    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS)
    local display = allegro5.al_create_display(800, 600)
    if not display then
        abort_example("Error creating display\n")
    end

    --log_printf("Display format = %d\n", al_get_display_format());

    local font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga", 0, 0)
    if not font then
        abort_example("Failed to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga\n")
    end

    --[[ Don't remove these braces. --]]
    ; (function()
        local theme = Theme(font)
        local prog = Prog(theme, display, bmp_filename)
        prog:run()
        prog:__destroy()
    end)()

    allegro5.al_destroy_font(font)

    close_log(false)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
