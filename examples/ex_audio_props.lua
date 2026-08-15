#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_audio_props.cpp
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
local ToggleButton = nihgui.ToggleButton
local Theme = nihgui.Theme
local VSlider = nihgui.VSlider

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 -    Example program for the Allegro library, by Peter Wang.
 -
 -    Test audio properties (gain and panning, for now).
 --]]

local font_gui
local sample
local sample_inst

local Prog = common.class({
    __name = "Prog",
    __destroy = function(self)
        self.d:__destroy()
    end,
})

function Prog.__init__(self, theme, display, instance_len)
    self.d = Dialog(theme, display, 40, 20)
    self.length_label = Label("Length")
    self.length_slider = HSlider(instance_len, instance_len)
    self.pan_button = ToggleButton("Pan")
    self.pan_slider = HSlider(1000, 2000)
    self.speed_label = Label("Speed")
    self.speed_slider = HSlider(1000, 5000)
    self.bidir_button = ToggleButton("Bidir")
    self.play_button = ToggleButton("Play")
    self.gain_label = Label("Gain")
    self.gain_slider = VSlider(1000, 2000)
    self.mixer_gain_label = Label("Mixer gain")
    self.mixer_gain_slider = VSlider(1000, 2000)
    self.two_label = Label("2.0")
    self.one_label = Label("1.0")
    self.zero_label = Label("0.0")

    self.pan_button:set_pushed(true)
    self.play_button:set_pushed(true)

    self.d:add(self.length_label, 2, 8, 4, 1)
    self.d:add(self.length_slider, 6, 8, 22, 1)

    self.d:add(self.pan_button, 2, 10, 4, 1)
    self.d:add(self.pan_slider, 6, 10, 22, 1)

    self.d:add(self.speed_label, 2, 12, 4, 1)
    self.d:add(self.speed_slider, 6, 12, 22, 1)

    self.d:add(self.bidir_button, 2, 14, 4, 1)
    self.d:add(self.play_button, 6, 14, 4, 1)

    self.d:add(self.gain_label, 29, 1, 2, 1)
    self.d:add(self.gain_slider, 29, 2, 2, 17)

    self.d:add(self.mixer_gain_label, 33, 1, 6, 1)
    self.d:add(self.mixer_gain_slider, 35, 2, 2, 17)

    self.d:add(self.two_label, 32, 2, 2, 1)
    self.d:add(self.one_label, 32, 10, 2, 1)
    self.d:add(self.zero_label, 32, 18, 2, 1)
end

function Prog.run(self)
    self.d:prepare()

    while not self.d:is_quit_requested() do
        if self.d:is_draw_requested() then
            self:update_properties()
            allegro5.al_clear_to_color(allegro5.al_map_rgb(128, 128, 128))
            self.d:draw()
            allegro5.al_flip_display()
        end

        self.d:run_step(true)
    end
end

function Prog.update_properties(self)
    local length = 0
    local pan = 0
    local speed = 0
    local gain = 0
    local mixer_gain = 0

    if self.pan_button:get_pushed() then
        pan = self.pan_slider:get_cur_value() / 1000.0 - 1.0
    else
        pan = allegro5.ALLEGRO_AUDIO_PAN_NONE
    end
    allegro5.al_set_sample_instance_pan(sample_inst, pan)

    speed = self.speed_slider:get_cur_value() / 1000.0
    allegro5.al_set_sample_instance_speed(sample_inst, speed)

    length = self.length_slider:get_cur_value()
    allegro5.al_set_sample_instance_length(sample_inst, length)

    if self.bidir_button:get_pushed() then
        allegro5.al_set_sample_instance_playmode(sample_inst, allegro5.ALLEGRO_PLAYMODE_BIDIR)
    else
        allegro5.al_set_sample_instance_playmode(sample_inst, allegro5.ALLEGRO_PLAYMODE_LOOP)
    end

    allegro5.al_set_sample_instance_playing(sample_inst, self.play_button:get_pushed())

    gain = self.gain_slider:get_cur_value() / 1000.0
    allegro5.al_set_sample_instance_gain(sample_inst, gain)

    mixer_gain = self.mixer_gain_slider:get_cur_value() / 1000.0
    allegro5.al_set_mixer_gain(allegro5.al_get_default_mixer(), mixer_gain)
end

local function main(argv)
    local argc = #argv

    local display
    local filename

    if argc >= 1 then
        filename = argv[1]
    else
        filename = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/welcome.wav"
    end

    if not allegro5.al_init() then
        abort_example("Could not init Allegro\n")
    end
    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()

    allegro5.al_init_font_addon()
    allegro5.al_init_primitives_addon()
    allegro5.al_init_acodec_addon()
    init_platform_specific()

    if not allegro5.al_install_audio() then
        abort_example("Could not init sound!\n")
    end

    if not allegro5.al_reserve_samples(1) then
        abort_example("Could not set up voice and mixer.\n")
    end

    sample = allegro5.al_load_sample(filename)
    if not sample then
        abort_example("Could not load sample from '%s'!\n", filename)
    end

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS)
    display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Unable to create display\n")
    end

    font_gui = allegro5.al_create_builtin_font()
    if not font_gui then
        abort_example("Failed to create builtin font\n")
    end

    --[[ Loop the sample. --]]
    sample_inst = allegro5.al_create_sample_instance(sample)
    allegro5.al_set_sample_instance_playmode(sample_inst, allegro5.ALLEGRO_PLAYMODE_LOOP)
    allegro5.al_attach_sample_instance_to_mixer(sample_inst, allegro5.al_get_default_mixer())
    allegro5.al_play_sample_instance(sample_inst)

    --[[ Don't remove these braces. --]]
    ; (function()
        local theme = Theme(font_gui)
        local prog = Prog(theme, display, allegro5.al_get_sample_instance_length(sample_inst))
        prog:run()
        prog:__destroy()
    end)()

    allegro5.al_destroy_sample_instance(sample_inst)
    allegro5.al_destroy_sample(sample)
    allegro5.al_uninstall_audio()

    allegro5.al_destroy_font(font_gui)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
