#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_blend2.cpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")
local nihgui = require("nihgui")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local new_table = common.new_table

local Dialog = nihgui.Dialog
local HSlider = nihgui.HSlider
local Label = nihgui.Label
local List = nihgui.List
local Theme = nihgui.Theme

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local allegro
local mysha
local allegro_bmp
local mysha_bmp
local target
local target_bmp

local Prog = common.class({
    __name = "Prog",
    __destroy = function (self)
        self.d:__destroy()
    end,
})

function Prog.__init__(self, theme, display)
    self.operation_label = new_table(Label, 6)
    self.operations = new_table(List, 6)
    self.rgba_label = {}

    self.d = Dialog(theme, display, 20, 40)
    self.memory_label = Label("Memory")
    self.texture_label = Label("Texture")
    self.source_label = Label("Source", false)
    self.destination_label = Label("Destination", false)
    self.source_image = List(0)
    self.destination_image = List(1)
    self.draw_mode = List(0)
    self.r = {}
    self.g = {}
    self.b = {}
    self.a = {}

    self.d:add(self.memory_label, 9, 0, 10, 2)
    self.d:add(self.texture_label, 0, 0, 10, 2)
    self.d:add(self.source_label, 1, 15, 6, 2)
    self.d:add(self.destination_label, 7, 15, 6, 2)

    local images = { self.source_image, self.destination_image, self.draw_mode }
    for i = 0, 3 - INDEX_BASE do
        local image = images[i + INDEX_BASE]
        if i < 2 then
            image:append_item("Mysha")
            image:append_item("Allegro")
            image:append_item("Mysha (tinted)")
            image:append_item("Allegro (tinted)")
            image:append_item("Color")
        else
            image:append_item("original")
            image:append_item("scaled")
            image:append_item("rotated")
        end
        self.d:add(image, 1 + i * 6, 16, 4, 6)
    end

    for i = 0, 4 - INDEX_BASE do
        self.operation_label[i + INDEX_BASE] = Label(
        (function() if i % 2 == 0 then return "Color" else return "Alpha" end end)(), false)
        self.d:add(self.operation_label[i + INDEX_BASE], 1 + i * 3, 23, 3, 2)
        local l = self.operations[i + INDEX_BASE]
        l:append_item("ONE")
        l:append_item("ZERO")
        l:append_item("ALPHA")
        l:append_item("INVERSE")
        l:append_item("SRC_COLOR")
        l:append_item("DEST_COLOR")
        l:append_item("INV_SRC_COLOR")
        l:append_item("INV_DEST_COLOR")
        l:append_item("CONST_COLOR")
        l:append_item("INV_CONST_COLOR")
        self.d:add(l, 1 + i * 3, 24, 3, 10)
    end

    for i = 4, 6 - INDEX_BASE do
        self.operation_label[i + INDEX_BASE] = Label(
        (function() if i == 4 then return "Blend op" else return "Alpha op" end end)(), false)
        self.d:add(self.operation_label[i + INDEX_BASE], 1 + i * 3, 23, 3, 2)
        local l = self.operations[i + INDEX_BASE]
        l:append_item("ADD")
        l:append_item("SRC_MINUS_DEST")
        l:append_item("DEST_MINUS_SRC")
        self.d:add(l, 1 + i * 3, 24, 3, 6)
    end

    self.rgba_label[0 + INDEX_BASE] = Label("Source tint/color RGBA")
    self.rgba_label[1 + INDEX_BASE] = Label("Dest tint/color RGBA")
    self.rgba_label[2 + INDEX_BASE] = Label("Const color RGBA")
    self.d:add(self.rgba_label[0 + INDEX_BASE], 1, 34, 5, 1)
    self.d:add(self.rgba_label[1 + INDEX_BASE], 7, 34, 5, 1)
    self.d:add(self.rgba_label[2 + INDEX_BASE], 13, 34, 5, 1)

    for i = 0, 3 - INDEX_BASE do
        self.r[i + INDEX_BASE] = HSlider(255, 255)
        self.g[i + INDEX_BASE] = HSlider(255, 255)
        self.b[i + INDEX_BASE] = HSlider(255, 255)
        self.a[i + INDEX_BASE] = HSlider(255, 255)
        self.d:add(self.r[i + INDEX_BASE], 1 + i * 6, 35, 5, 1)
        self.d:add(self.g[i + INDEX_BASE], 1 + i * 6, 36, 5, 1)
        self.d:add(self.b[i + INDEX_BASE], 1 + i * 6, 37, 5, 1)
        self.d:add(self.a[i + INDEX_BASE], 1 + i * 6, 38, 5, 1)
    end
end

function Prog.run(self)
    self.d:prepare()

    while not self.d:is_quit_requested() do
        if self.d:is_draw_requested() then
            allegro5.al_clear_to_color(allegro5.al_map_rgb(128, 128, 128))
            self:draw_samples()
            self.d:draw()
            allegro5.al_flip_display()
        end

        self.d:run_step(true)
    end
end

local function str_to_blend_mode(str)
    if str == "ZERO" then
        return allegro5.ALLEGRO_ZERO
    end
    if str == "ONE" then
        return allegro5.ALLEGRO_ONE
    end
    if str == "SRC_COLOR" then
        return allegro5.ALLEGRO_SRC_COLOR
    end
    if str == "DEST_COLOR" then
        return allegro5.ALLEGRO_DEST_COLOR
    end
    if str == "INV_SRC_COLOR" then
        return allegro5.ALLEGRO_INVERSE_SRC_COLOR
    end
    if str == "INV_DEST_COLOR" then
        return allegro5.ALLEGRO_INVERSE_DEST_COLOR
    end
    if str == "ALPHA" then
        return allegro5.ALLEGRO_ALPHA
    end
    if str == "INVERSE" then
        return allegro5.ALLEGRO_INVERSE_ALPHA
    end
    if str == "ADD" then
        return allegro5.ALLEGRO_ADD
    end
    if str == "SRC_MINUS_DEST" then
        return allegro5.ALLEGRO_SRC_MINUS_DEST
    end
    if str == "DEST_MINUS_SRC" then
        return allegro5.ALLEGRO_DEST_MINUS_SRC
    end
    if str == "CONST_COLOR" then
        return allegro5.ALLEGRO_CONST_COLOR
    end
    if str == "INV_CONST_COLOR" then
        return allegro5.ALLEGRO_INVERSE_CONST_COLOR
    end

    allegro5.ALLEGRO_ASSERT(false)
    return allegro5.ALLEGRO_ONE
end

local function draw_background(x, y)
    local c = {
        allegro5.al_map_rgba(0x66, 0x66, 0x66, 0xff),
        allegro5.al_map_rgba(0x99, 0x99, 0x99, 0xff)
    }

    for i = 0, 320 / 16 - INDEX_BASE do
        for j = 0, 200 / 16 - INDEX_BASE do
            allegro5.al_draw_filled_rectangle(x + i * 16, y + j * 16,
                x + i * 16 + 16, y + j * 16 + 16,
                c[bit.band((i + j), 1) + INDEX_BASE])
        end
    end
end

local function makecol(r, g, b, a)
    --[[ Premultiply alpha. --]]
    local rf = r / 255.0
    local gf = g / 255.0
    local bf = b / 255.0
    local af = a / 255.0
    return allegro5.al_map_rgba_f(rf * af, gf * af, bf * af, af)
end

local function contains(haystack, needle)
    return string.find(haystack, needle) ~= nil
end

function Prog.draw_bitmap(self, str, how, memory, destination)
    local i = (function() if destination then return 1 else return 0 end end)()
    local rv = self.r[i + INDEX_BASE]:get_cur_value()
    local gv = self.g[i + INDEX_BASE]:get_cur_value()
    local bv = self.b[i + INDEX_BASE]:get_cur_value()
    local av = self.a[i + INDEX_BASE]:get_cur_value()
    local color = makecol(rv, gv, bv, av)
    local bmp

    if contains(str, "Mysha") then
        bmp = (function() if memory then return mysha_bmp else return mysha end end)()
    else
        bmp = (function() if memory then return allegro_bmp else return allegro end end)()
    end

    if how == "original" then
        if str == "Color" then
            allegro5.al_draw_filled_rectangle(0, 0, 320, 200, color)
        elseif contains(str, "tint") then
            allegro5.al_draw_tinted_bitmap(bmp, color, 0, 0, 0)
        else
            allegro5.al_draw_bitmap(bmp, 0, 0, 0)
        end
    elseif how == "scaled" then
        local w = allegro5.al_get_bitmap_width(bmp)
        local h = allegro5.al_get_bitmap_height(bmp)
        local s = 200.0 / h * 0.9
        if str == "Color" then
            allegro5.al_draw_filled_rectangle(10, 10, 300, 180, color)
        elseif contains(str, "tint") then
            allegro5.al_draw_tinted_scaled_bitmap(bmp, color, 0, 0, w, h,
                160 - w * s / 2, 100 - h * s / 2, w * s, h * s, 0)
        else
            allegro5.al_draw_scaled_bitmap(bmp, 0, 0, w, h,
                160 - w * s / 2, 100 - h * s / 2, w * s, h * s, 0)
        end
    elseif how == "rotated" then
        if str == "Color" then
            allegro5.al_draw_filled_circle(160, 100, 100, color)
        elseif contains(str, "tint") then
            allegro5.al_draw_tinted_rotated_bitmap(bmp, color, 160, 100,
                160, 100, allegro5.ALLEGRO_PI / 8, 0)
        else
            allegro5.al_draw_rotated_bitmap(bmp, 160, 100,
                160, 100, allegro5.ALLEGRO_PI / 8, 0)
        end
    end
end

function Prog.blending_test(self, memory)
    local transparency = allegro5.al_map_rgba_f(0, 0, 0, 0)
    local op = str_to_blend_mode(self.operations[4 + INDEX_BASE]:get_selected_item_text())
    local aop = str_to_blend_mode(self.operations[5 + INDEX_BASE]:get_selected_item_text())
    local src = str_to_blend_mode(self.operations[0 + INDEX_BASE]:get_selected_item_text())
    local asrc = str_to_blend_mode(self.operations[1 + INDEX_BASE]:get_selected_item_text())
    local dst = str_to_blend_mode(self.operations[2 + INDEX_BASE]:get_selected_item_text())
    local adst = str_to_blend_mode(self.operations[3 + INDEX_BASE]:get_selected_item_text())
    local rv = self.r[2 + INDEX_BASE]:get_cur_value()
    local gv = self.g[2 + INDEX_BASE]:get_cur_value()
    local bv = self.b[2 + INDEX_BASE]:get_cur_value()
    local av = self.a[2 + INDEX_BASE]:get_cur_value()
    local color = makecol(rv, gv, bv, av)

    --[[ Initialize with destination. --]]
    allegro5.al_clear_to_color(transparency); -- Just in case.
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
    self:draw_bitmap(self.destination_image:get_selected_item_text(),
        "original", memory, true)

    --[[ Now draw the blended source over it. --]]
    allegro5.al_set_separate_blender(op, src, dst, aop, asrc, adst)
    allegro5.al_set_blend_color(color)
    self:draw_bitmap(self.source_image:get_selected_item_text(),
        self.draw_mode:get_selected_item_text(), memory, false)
end

function Prog.draw_samples(self)
    local state = allegro5.ALLEGRO_STATE()
    allegro5.al_store_state(state, bit.bor(allegro5.ALLEGRO_STATE_TARGET_BITMAP, allegro5.ALLEGRO_STATE_BLENDER))

    --[[ Draw a background, in case our target bitmap will end up with
    - alpha in it.
    --]]
    draw_background(40, 20)
    draw_background(400, 20)

    --[[ Test standard blending. --]]
    allegro5.al_set_target_bitmap(target)
    self:blending_test(false)

    --[[ Test memory blending. --]]
    allegro5.al_set_target_bitmap(target_bmp)
    self:blending_test(true)

    --[[ Display results. --]]
    allegro5.al_restore_state(state)
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
    allegro5.al_draw_bitmap(target, 40, 20, 0)
    allegro5.al_draw_bitmap(target_bmp, 400, 20, 0)

    allegro5.al_restore_state(state)
end

local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro\n")
    end
    allegro5.al_init_primitives_addon()
    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()

    allegro5.al_init_font_addon()
    allegro5.al_init_image_addon()
    init_platform_specific()

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS)
    local display = allegro5.al_create_display(800, 600)
    if not display then
        abort_example("Unable to create display\n")
    end

    local font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga", 0, 0)
    if not font then
        abort_example("Failed to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga\n")
    end
    allegro = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/allegro.pcx")
    if not allegro then
        abort_example("Failed to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/allegro.pcx\n")
    end
    mysha = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha256x256.png")
    if not mysha then
        abort_example("Failed to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha256x256.png\n")
    end

    target = allegro5.al_create_bitmap(320, 200)

    allegro5.al_add_new_bitmap_flag(allegro5.ALLEGRO_MEMORY_BITMAP)
    allegro_bmp = allegro5.al_clone_bitmap(allegro)
    mysha_bmp = allegro5.al_clone_bitmap(mysha)
    target_bmp = allegro5.al_clone_bitmap(target)

    --[[ Don't remove these braces. --]]
    ; (function()
        local theme = Theme(font)
        local prog = Prog(theme, display)
        prog:run()
        prog:__destroy()
    end)()

    allegro5.al_destroy_bitmap(allegro)
    allegro5.al_destroy_bitmap(allegro_bmp)
    allegro5.al_destroy_bitmap(mysha)
    allegro5.al_destroy_bitmap(mysha_bmp)
    allegro5.al_destroy_bitmap(target)
    allegro5.al_destroy_bitmap(target_bmp)

    allegro5.al_destroy_font(font)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
