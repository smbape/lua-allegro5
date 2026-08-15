#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_haptic2.cpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")
local nihgui = require("nihgui")

local env = common.env

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf
local new_table = common.new_table

local Button = nihgui.Button
local Dialog = nihgui.Dialog
local HSlider = nihgui.HSlider
local Label = nihgui.Label
local List = nihgui.List
local Theme = nihgui.Theme

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 -    Example program for the Allegro library, by Beoran.
 -
 -    Exhaustive haptics example.
 --]]

local function Haptic()
    return {
        haptic = nil,
        effect = allegro5.ALLEGRO_HAPTIC_EFFECT(),
        id = allegro5.ALLEGRO_HAPTIC_EFFECT_ID(),
        name = nil,
        playing = false,
    }
end

local EX_MAX_HAPTICS = 8

local haptics = new_table(Haptic, EX_MAX_HAPTICS)
local num_haptics = 0
local joystick_queue
local update_timer = nil

local function release_all_haptics()
    for i = 0, num_haptics - INDEX_BASE do
        allegro5.al_release_haptic(haptics[i + INDEX_BASE].haptic)
        haptics[i + INDEX_BASE].haptic = nil
    end
end

local function get_all_haptics()
    num_haptics = 0
    local display = allegro5.al_get_current_display()

    if allegro5.al_is_display_haptic(display) then
        haptics[num_haptics + INDEX_BASE].haptic = allegro5.al_get_haptic_from_display(display)
        if haptics[num_haptics + INDEX_BASE].haptic then
            haptics[num_haptics + INDEX_BASE].name = "display"
            haptics[num_haptics + INDEX_BASE].playing = false
            num_haptics = num_haptics + 1
        end
    end

    local i = 0
    while num_haptics < EX_MAX_HAPTICS and i < allegro5.al_get_num_joysticks() do
        local joy = allegro5.al_get_joystick(i)
        if allegro5.al_is_joystick_haptic(joy) then
            haptics[num_haptics + INDEX_BASE].haptic = allegro5.al_get_haptic_from_joystick(joy)
            if haptics[num_haptics + INDEX_BASE].haptic then
                local name = allegro5.al_get_joystick_name(joy)
                haptics[num_haptics + INDEX_BASE].name = name
                haptics[num_haptics + INDEX_BASE].playing = false
                num_haptics = num_haptics + 1
            end
        end
        i = i + 1
    end
end

local function CapacityName(value, name)
    if value == nil then value = 0 end
    return {
        value = value,
        name = name,
    }
end

local capname = new_table(CapacityName, {
    { allegro5.ALLEGRO_HAPTIC_RUMBLE,   "ALLEGRO_HAPTIC_RUMBLE" },
    { allegro5.ALLEGRO_HAPTIC_PERIODIC, "ALLEGRO_HAPTIC_PERIODIC" },
    { allegro5.ALLEGRO_HAPTIC_CONSTANT, "ALLEGRO_HAPTIC_CONSTANT" },
    { allegro5.ALLEGRO_HAPTIC_SPRING,   "ALLEGRO_HAPTIC_SPRING" },
    { allegro5.ALLEGRO_HAPTIC_FRICTION, "ALLEGRO_HAPTIC_FRICTION" },
    { allegro5.ALLEGRO_HAPTIC_DAMPER,   "ALLEGRO_HAPTIC_DAMPER" },
    { allegro5.ALLEGRO_HAPTIC_INERTIA,  "ALLEGRO_HAPTIC_INERTIA" },
    { allegro5.ALLEGRO_HAPTIC_RAMP,     "ALLEGRO_HAPTIC_RAMP" },
    { allegro5.ALLEGRO_HAPTIC_SQUARE,   "ALLEGRO_HAPTIC_SQUARE" },
    { allegro5.ALLEGRO_HAPTIC_TRIANGLE, "ALLEGRO_HAPTIC_TRIANGLE" },
    { allegro5.ALLEGRO_HAPTIC_SINE,     "ALLEGRO_HAPTIC_SINE" },
    { allegro5.ALLEGRO_HAPTIC_SAW_UP,   "ALLEGRO_HAPTIC_SAW_UP" },
    { allegro5.ALLEGRO_HAPTIC_SAW_DOWN, "ALLEGRO_HAPTIC_SAW_DOWN" },
    { allegro5.ALLEGRO_HAPTIC_CUSTOM,   "ALLEGRO_HAPTIC_CUSTOM" },
    { allegro5.ALLEGRO_HAPTIC_GAIN,     "ALLEGRO_HAPTIC_GAIN" },
    { allegro5.ALLEGRO_HAPTIC_ANGLE,    "ALLEGRO_HAPTIC_ANGLE" },
    { allegro5.ALLEGRO_HAPTIC_RADIUS,   "ALLEGRO_HAPTIC_RADIUS" },
    { allegro5.ALLEGRO_HAPTIC_AZIMUTH,  "ALLEGRO_HAPTIC_AZIMUTH" }
})

local EX_START_TYPES = 0
local EX_MAX_TYPES = 8
local EX_END_TYPES = 8

local EX_START_WAVES = 8
local EX_END_WAVES = 13
local EX_MAX_WAVES = 5
--[[ Ignore custom waveforms for now... --]]

local EX_START_COORDS = 15
local EX_MAX_COORDS = 3
local EX_END_COORDS = 18

local CanStopAndPlay = common.class({
    __name = "CanStopAndPlay",

    on_play = function(self)
        error("on_play must be implemented")
    end,

    on_stop = function(self)
        error("on_stop must be implemented")
    end,
})

local PlayButton = common.class({
    __name = "PlayButton",
}, Button)

function PlayButton.__init__(self, snp)
    Button.__init__(self, "Play")
    self.stop_and_play = snp
end

function PlayButton.on_click(self, mx, my)
    if self:is_disabled() then
        return
    end
    log_printf("Start playing...\n")
    if self.stop_and_play then
        self.stop_and_play:on_play()
    end
end

local StopButton = common.class({
    __name = "StopButton",
}, Button)

function StopButton.__init__(self, snp)
    Button.__init__(self, "Stop")
    self.stop_and_play = snp
end

function StopButton.on_click(self, mx, my)
    if self:is_disabled() then
        return
    end
    log_printf("Stop playing...\n")
    if self.stop_and_play then
        self.stop_and_play:on_stop()
    end
end

local Prog = common.class({
    __name = "Prog",
    __destroy = function(self)
        self.d:__destroy()
    end,
}, CanStopAndPlay)

function Prog.__init__(self, theme, display)
    self.d = Dialog(theme, display, 20, 40)
    self.device_list = List(0)
    self.type_list = List(0)
    self.waveform_list = List(0)
    self.device_label = Label("Haptic Device")
    self.type_label = Label("Haptic Effect Type")
    self.waveform_label = Label("Wave Form Periodic Effect")
    self.length_slider = HSlider(1, 10)
    self.delay_slider = HSlider(1, 10)
    self.loops_slider = HSlider(1, 10)
    self.replay_label = Label("Replay")
    self.length_label = Label("Length", false)
    self.delay_label = Label("Delay", false)
    self.loops_label = Label("Loops")
    self.attack_length_slider = HSlider(2, 10)
    self.attack_level_slider = HSlider(4, 10)
    self.fade_length_slider = HSlider(2, 10)
    self.fade_level_slider = HSlider(4, 10)
    self.envelope_label = Label("Envelope")
    self.attack_length_label = Label("Attack Length", false)
    self.attack_level_label = Label("Attack Level", false)
    self.fade_length_label = Label("Fade Length", false)
    self.fade_level_label = Label("Fade Level", false)
    self.angle_slider = HSlider(0, 360)
    self.radius_slider = HSlider(0, 10)
    self.azimuth_slider = HSlider(180, 360)
    self.coordinates_label = Label("Coordinates")
    self.angle_label = Label("Angle", false)
    self.radius_label = Label("Radius", false)
    self.azimuth_label = Label("Azimuth", false)
    self.level_slider = HSlider(5, 10)
    self.constant_effect_label = Label("Constant Effect")
    self.level_label = Label("Level", false)
    self.start_level_slider = HSlider(3, 10)
    self.end_level_slider = HSlider(7, 10)
    self.ramp_effect_label = Label("Ramp Effect")
    self.start_level_label = Label("Start Level", false)
    self.end_level_label = Label("End Level", false)
    self.right_saturation_slider = HSlider(5, 10)
    self.right_coeff_slider = HSlider(5, 10)
    self.left_saturation_slider = HSlider(5, 10)
    self.left_coeff_slider = HSlider(5, 10)
    self.deadband_slider = HSlider(1, 10)
    self.center_slider = HSlider(5, 10)
    self.right_saturation_label = Label("Right Saturation", false)
    self.right_coeff_label = Label("Right Coefficient", false)
    self.left_saturation_label = Label("Left Saturation", false)
    self.left_coeff_label = Label("Left Coefficient", false)
    self.condition_effect_label = Label("Condition Effect")
    self.deadband_label = Label("Deadband", false)
    self.center_label = Label("Center", false)
    self.period_slider = HSlider(1, 10)
    self.magnitude_slider = HSlider(5, 10)
    self.offset_slider = HSlider(0, 10)
    self.phase_slider = HSlider(0, 10)
    self.periodic_effect_label = Label("Periodic Effect")
    self.period_label = Label("Period", false)
    self.magnitude_label = Label("Magnitude", false)
    self.offset_label = Label("Offset", false)
    self.phase_label = Label("Phase", false)
    self.strong_magnitude_slider = HSlider(5, 10)
    self.weak_magnitude_slider = HSlider(5, 10)
    self.rumble_effect_label = Label("Rumble effect")
    self.strong_magnitude_label = Label("Strong Magnitude", false)
    self.weak_magnitude_label = Label("Weak Magnitude", false)
    self.gain_slider = HSlider(10, 10)
    self.gain_label = Label("Gain")
    self.autocenter_slider = HSlider(0, 10)
    self.autocenter_label = Label("Autocenter")
    self.message_label = Label("Ready.", false)
    self.message_label_label = Label("Status", false)
    self.play_button = PlayButton(self)
    self.stop_button = StopButton(self)
    self.last_haptic = nil
    self.show_haptic = nil

    for i = 1, num_haptics do
        self.device_list:append_item(haptics[i].name)
    end
    self.d:add(self.device_label, 0, 1, 7, 1)
    self.d:add(self.device_list, 0, 2, 7, 8)

    for i = EX_START_TYPES, EX_END_TYPES - INDEX_BASE do
        self.type_list:append_item(capname[i + INDEX_BASE].name)
    end
    self.d:add(self.type_label, 7, 1, 6, 1)
    self.d:add(self.type_list, 7, 2, 6, 8)

    for i = EX_START_WAVES, EX_END_WAVES - INDEX_BASE do
        self.waveform_list:append_item(capname[i + INDEX_BASE].name)
    end
    self.d:add(self.waveform_label, 13, 1, 7, 1)
    self.d:add(self.waveform_list, 13, 2, 7, 8)

    self.d:add(self.replay_label, 0, 11, 7, 1)
    self.d:add(self.length_label, 0, 12, 2, 1)
    self.d:add(self.length_slider, 2, 12, 5, 1)
    self.d:add(self.delay_label, 0, 13, 2, 1)
    self.d:add(self.delay_slider, 2, 13, 5, 1)

    self.d:add(self.loops_label, 7, 11, 7, 1)
    self.d:add(self.loops_slider, 7, 12, 6, 1)
    self.d:add(self.gain_label, 13, 11, 7, 1)
    self.d:add(self.gain_slider, 13, 12, 7, 1)

    self.d:add(self.autocenter_label, 13, 13, 7, 1)
    self.d:add(self.autocenter_slider, 13, 14, 7, 1)


    self.d:add(self.envelope_label, 0, 15, 9, 1)
    self.d:add(self.attack_length_label, 0, 16, 3, 1)
    self.d:add(self.attack_length_slider, 4, 16, 6, 1)
    self.d:add(self.attack_level_label, 0, 17, 3, 1)
    self.d:add(self.attack_level_slider, 4, 17, 6, 1)
    self.d:add(self.fade_length_label, 0, 18, 3, 1)
    self.d:add(self.fade_length_slider, 4, 18, 6, 1)
    self.d:add(self.fade_level_label, 0, 19, 3, 1)
    self.d:add(self.fade_level_slider, 4, 19, 6, 1)

    self.d:add(self.coordinates_label, 11, 15, 9, 1)
    self.d:add(self.angle_label, 11, 16, 2, 1)
    self.d:add(self.angle_slider, 13, 16, 7, 1)
    self.d:add(self.radius_label, 11, 17, 2, 1)
    self.d:add(self.radius_slider, 13, 17, 7, 1)
    self.d:add(self.azimuth_label, 11, 18, 2, 1)
    self.d:add(self.azimuth_slider, 13, 18, 7, 1)

    self.d:add(self.condition_effect_label, 0, 21, 9, 1)
    self.d:add(self.right_coeff_label, 0, 22, 4, 1)
    self.d:add(self.right_coeff_slider, 4, 22, 6, 1)
    self.d:add(self.right_saturation_label, 0, 23, 4, 1)
    self.d:add(self.right_saturation_slider, 4, 23, 6, 1)
    self.d:add(self.left_coeff_label, 0, 24, 4, 1)
    self.d:add(self.left_coeff_slider, 4, 24, 6, 1)
    self.d:add(self.left_saturation_label, 0, 25, 4, 1)
    self.d:add(self.left_saturation_slider, 4, 25, 6, 1)
    self.d:add(self.deadband_label, 0, 26, 4, 1)
    self.d:add(self.deadband_slider, 4, 26, 6, 1)
    self.d:add(self.center_label, 0, 27, 4, 1)
    self.d:add(self.center_slider, 4, 27, 6, 1)

    self.d:add(self.periodic_effect_label, 11, 21, 9, 1)
    self.d:add(self.period_label, 11, 22, 2, 1)
    self.d:add(self.period_slider, 13, 22, 7, 1)
    self.d:add(self.magnitude_label, 11, 23, 2, 1)
    self.d:add(self.magnitude_slider, 13, 23, 7, 1)
    self.d:add(self.offset_label, 11, 24, 2, 1)
    self.d:add(self.offset_slider, 13, 24, 7, 1)
    self.d:add(self.phase_label, 11, 25, 2, 1)
    self.d:add(self.phase_slider, 13, 25, 7, 1)

    self.d:add(self.ramp_effect_label, 11, 29, 9, 1)
    self.d:add(self.start_level_label, 11, 30, 2, 1)
    self.d:add(self.start_level_slider, 13, 30, 7, 1)
    self.d:add(self.end_level_label, 11, 31, 2, 1)
    self.d:add(self.end_level_slider, 13, 31, 7, 1)

    self.d:add(self.rumble_effect_label, 0, 29, 9, 1)
    self.d:add(self.strong_magnitude_label, 0, 30, 4, 1)
    self.d:add(self.strong_magnitude_slider, 4, 30, 6, 1)
    self.d:add(self.weak_magnitude_label, 0, 31, 4, 1)
    self.d:add(self.weak_magnitude_slider, 4, 31, 6, 1)

    self.d:add(self.constant_effect_label, 0, 33, 9, 1)
    self.d:add(self.level_label, 0, 34, 3, 1)
    self.d:add(self.level_slider, 4, 34, 6, 1)

    self.d:add(self.message_label_label, 0, 36, 2, 1)
    self.d:add(self.message_label, 2, 36, 12, 1)

    self.d:add(self.play_button, 6, 38, 3, 2)
    self.d:add(self.stop_button, 12, 38, 3, 2)

    self.d:register_event_source(allegro5.al_get_timer_event_source(update_timer))
end

function Prog.update(self)
    --[[ Update playing state and display. --]]
    if self.last_haptic and self.last_haptic.playing then
        if not allegro5.al_is_haptic_effect_playing(self.last_haptic.id) then
            self.last_haptic.playing = false
            allegro5.al_release_haptic_effect(self.last_haptic.id)
            self.message_label:set_text("Done.")
            self.play_button:set_disabled(false)
            self.d:request_draw()
            log_printf("Play done on %s\n", self.last_haptic.name)
        end
    end

    local e = allegro5.ALLEGRO_EVENT()

    --[[ Check for hot plugging--]]
    while allegro5.al_get_next_event(joystick_queue, e) do
        --[[ clear, reconfigure and fetch haptics again. --]]
        if e.type == allegro5.ALLEGRO_EVENT_JOYSTICK_CONFIGURATION then
            allegro5.al_reconfigure_joysticks()
            release_all_haptics()
            get_all_haptics()
            self.device_list:clear_items()
            for i = 0, num_haptics - INDEX_BASE do
                self.device_list:append_item(haptics[i + INDEX_BASE].name)
            end
            log_printf("Hot plugging detected...\n")
            self.message_label:set_text("Hot Plugging...")
            self.play_button:set_disabled(false)
            self.d:request_draw()
        end
    end

    --[[ Update availability of controls based on capabilities. --]]
    local devno = self.device_list:get_cur_value()
    local dev = haptics[devno + INDEX_BASE]
    if dev and dev.haptic then
        if dev ~= self.show_haptic then
            self.play_button:set_disabled(false)
            self:update_controls(dev)
            self.show_haptic = dev
            self.message_label:set_text("Haptic Device Found.")
            self.d:request_draw()
        end
    else
        self.play_button:set_disabled(true)
        self.message_label:set_text("No Haptic Device.")
        self.d:request_draw()
    end
end

function Prog.run(self)
    self.d:prepare()

    while not self.d:is_quit_requested() do
        self:update()
        if self.d:is_draw_requested() then
            allegro5.al_clear_to_color(allegro5.al_map_rgb(128, 148, 168))
            self.d:draw()
            allegro5.al_flip_display()
        end

        self.d:run_step(true)
    end

    --[[ Stop playing anything we were still playing. --]]
    self:on_stop()
end

local function TEST_CAP(CAP, FLAG) return bit.band(CAP, FLAG) == FLAG end

function Prog.update_controls(self, dev)
    --[[ Take a deep breath, here we go... --]]
    local cap = 0
    if dev then
        cap = allegro5.al_get_haptic_capabilities(dev.haptic)
    end

    --[[ Gain capability --]]
    self.gain_slider:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_GAIN))
    self.gain_label:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_GAIN))

    --[[ Autocenter capability --]]
    self.autocenter_slider:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_AUTOCENTER))
    self.autocenter_label:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_AUTOCENTER))


    --[[ Envelope related capabilities and sliders. --]]
    local envelope = TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_PERIODIC) or
        TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_CONSTANT) or
        TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_RAMP)

    self.envelope_label:set_disabled(not envelope)
    self.attack_level_slider:set_disabled(not envelope)
    self.attack_length_slider:set_disabled(not envelope)
    self.fade_level_slider:set_disabled(not envelope)
    self.fade_length_slider:set_disabled(not envelope)
    self.attack_level_label:set_disabled(not envelope)
    self.attack_length_label:set_disabled(not envelope)
    self.fade_level_label:set_disabled(not envelope)
    self.fade_length_label:set_disabled(not envelope)

    --[[ Coordinate related capabilities. --]]
    self.angle_slider:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_ANGLE))
    self.angle_label:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_ANGLE))
    self.radius_slider:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_RADIUS))
    self.radius_label:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_RADIUS))
    self.azimuth_slider:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_AZIMUTH))
    self.azimuth_label:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_AZIMUTH))

    --[[ Condition effect related capabilities. --]]
    local condition = TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_DAMPER) or
        TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_FRICTION) or
        TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_INERTIA) or
        TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_SPRING)

    self.condition_effect_label:set_disabled(not condition)
    self.right_coeff_slider:set_disabled(not condition)
    self.left_coeff_slider:set_disabled(not condition)
    self.right_saturation_slider:set_disabled(not condition)
    self.left_saturation_slider:set_disabled(not condition)
    self.center_slider:set_disabled(not condition)
    self.deadband_slider:set_disabled(not condition)
    self.right_coeff_label:set_disabled(not condition)
    self.left_coeff_label:set_disabled(not condition)
    self.right_saturation_label:set_disabled(not condition)
    self.left_saturation_label:set_disabled(not condition)
    self.center_label:set_disabled(not condition)
    self.deadband_label:set_disabled(not condition)

    --[[ Constant effect related capabilities. --]]
    self.constant_effect_label:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_CONSTANT))
    self.level_slider:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_CONSTANT))
    self.level_label:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_CONSTANT))

    --[[ Ramp effect capabilities. --]]
    self.ramp_effect_label:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_RAMP))
    self.start_level_slider:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_RAMP))
    self.start_level_label:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_RAMP))
    self.end_level_slider:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_RAMP))
    self.end_level_label:set_disabled(not TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_RAMP))

    --[[ Period effect capabilities. --]]
    local periodic = TEST_CAP(cap, allegro5.ALLEGRO_HAPTIC_PERIODIC)
    self.waveform_label:set_disabled(not periodic)
    self.waveform_list:set_disabled(not periodic)
    self.periodic_effect_label:set_disabled(not periodic)
    self.period_slider:set_disabled(not periodic)
    self.magnitude_slider:set_disabled(not periodic)
    self.offset_slider:set_disabled(not periodic)
    self.phase_slider:set_disabled(not periodic)
    self.period_label:set_disabled(not periodic)
    self.magnitude_label:set_disabled(not periodic)
    self.offset_label:set_disabled(not periodic)
    self.phase_label:set_disabled(not periodic)

    --[[ Change list of supported effect types. --]]
    self.type_list:clear_items()
    for i = EX_START_TYPES, EX_END_TYPES - INDEX_BASE do
        local cn = capname[i + INDEX_BASE]
        if TEST_CAP(cap, cn.value) then
            self.type_list:append_item(cn.name)
        end
    end

    --[[ Change list of supported wave form types. --]]
    self.waveform_list:clear_items()
    for i = EX_START_WAVES, EX_END_WAVES - INDEX_BASE do
        local cn = capname[i + INDEX_BASE]
        if TEST_CAP(cap, cn.value) then
            self.waveform_list:append_item(cn.name)
        end
    end
end

local function name_to_cap(name)
    for i = 0, EX_END_WAVES - INDEX_BASE do
        if name == capname[i + INDEX_BASE].name then
            return capname[i + INDEX_BASE].value
        end
    end
    return -1
end

local function cap_to_name(cap)
    for i = 0, EX_END_WAVES - INDEX_BASE do
        if cap == capname[i + INDEX_BASE].value then
            return capname[i + INDEX_BASE].name
        end
    end
    return "unknown"
end

local function slider_to_magnitude(slider)
    local value = slider:get_cur_value()
    local max = slider:get_max_value()
    return value / max
end

local function slider_to_duration(slider)
    local value = slider:get_cur_value()
    local max = 1.0
    return value / max
end

local function slider_to_angle(slider)
    local value = slider:get_cur_value()
    local max = slider:get_max_value()
    return value / max
end

function Prog.get_envelope(self, envelope)
    if not envelope then
        return
    end
    envelope.attack_length = slider_to_duration(self.attack_length_slider)
    envelope.fade_length = slider_to_duration(self.fade_length_slider)
    envelope.attack_level = slider_to_magnitude(self.attack_level_slider)
    envelope.fade_level = slider_to_magnitude(self.fade_level_slider)
end

function Prog.on_play(self)
    local devno = self.device_list:get_cur_value()
    if devno < 0 or devno >= num_haptics then
        self.message_label:set_text("No Haptic Device!")
        log_printf("No such device: %d\n", devno)
        return
    end

    local haptic = haptics[devno + INDEX_BASE]
    if not haptic or not haptic.haptic then
        log_printf("Device is NULL: %d\n", devno)
        self.message_label:set_text("Device Is NULL!")
        return
    end

    if not allegro5.al_is_haptic_active(haptic.haptic) then
        self.message_label:set_text("Device Not Active!")
        log_printf("Device is not active: %d\n", devno)
        return
    end

    --[[ Stop playing previous effect. --]]
    if haptic.playing then
        allegro5.al_stop_haptic_effect(haptic.id)
        haptic.playing = false
        allegro5.al_release_haptic_effect(haptic.id)
    end

    --[[ First set gain. --]]
    local gain = slider_to_magnitude(self.gain_slider)
    allegro5.al_set_haptic_gain(haptic.haptic, gain)

    --[[ Set autocentering. --]]
    local autocenter = slider_to_magnitude(self.autocenter_slider)
    allegro5.al_set_haptic_autocenter(haptic.haptic, autocenter)


    --[[ Now fill in the effect struct. --]]
    local _type = name_to_cap(self.type_list:get_selected_item_text())
    local wavetype = name_to_cap(self.waveform_list:get_selected_item_text())

    if _type < 0 then
        self.message_label:set_text("Unknown Effect Type!")
        log_printf("Unknown effect type: %d on %s\n", _type, haptic.name)
        return
    end

    if (wavetype < 0) and (_type == allegro5.ALLEGRO_HAPTIC_PERIODIC) then
        self.message_label:set_text("Unknown Wave Form!")
        log_printf("Unknown wave type: %d on %s\n", wavetype, haptic.name)
        return
    end

    haptic.effect.type = _type
    haptic.effect.replay.delay = slider_to_duration(self.delay_slider)
    haptic.effect.replay.length = slider_to_duration(self.length_slider)
    local loops = self.loops_slider:get_cur_value()
    haptic.effect.direction.angle = slider_to_angle(self.angle_slider)
    haptic.effect.direction.radius = slider_to_magnitude(self.angle_slider)
    haptic.effect.direction.azimuth = slider_to_angle(self.angle_slider)


    if _type == allegro5.ALLEGRO_HAPTIC_RUMBLE then
        haptic.effect.data.rumble.strong_magnitude = slider_to_magnitude(self.strong_magnitude_slider)
        haptic.effect.data.rumble.weak_magnitude = slider_to_magnitude(self.weak_magnitude_slider)
    elseif _type == allegro5.ALLEGRO_HAPTIC_PERIODIC then
        self:get_envelope(haptic.effect.data.periodic.envelope)
        haptic.effect.data.periodic.waveform = wavetype
        haptic.effect.data.periodic.magnitude = slider_to_magnitude(self.magnitude_slider)
        haptic.effect.data.periodic.period = slider_to_duration(self.period_slider)
        haptic.effect.data.periodic.offset = slider_to_duration(self.offset_slider)
        haptic.effect.data.periodic.phase = slider_to_duration(self.phase_slider)
        haptic.effect.data.periodic.custom_len = 0
        haptic.effect.data.periodic.custom_data = nil
    elseif _type == allegro5.ALLEGRO_HAPTIC_CONSTANT then
        self:get_envelope(haptic.effect.data.constant.envelope)
        haptic.effect.data.constant.level = slider_to_magnitude(self.level_slider)
    elseif _type == allegro5.ALLEGRO_HAPTIC_RAMP then
        self:get_envelope(haptic.effect.data.ramp.envelope)
        haptic.effect.data.ramp.start_level = slider_to_magnitude(self.start_level_slider)
        haptic.effect.data.ramp.end_level = slider_to_magnitude(self.end_level_slider)
    elseif _type == allegro5.ALLEGRO_HAPTIC_SPRING
        or _type == allegro5.ALLEGRO_HAPTIC_FRICTION
        or _type == allegro5.ALLEGRO_HAPTIC_DAMPER
        or _type == allegro5.ALLEGRO_HAPTIC_INERTIA --[[ fall through. --]] then
        haptic.effect.data.condition.right_saturation = slider_to_magnitude(self.right_saturation_slider)
        haptic.effect.data.condition.left_saturation = slider_to_magnitude(self.left_saturation_slider)
        haptic.effect.data.condition.right_coeff = slider_to_magnitude(self.right_coeff_slider)
        haptic.effect.data.condition.left_coeff = slider_to_magnitude(self.left_coeff_slider)
        haptic.effect.data.condition.deadband = slider_to_magnitude(self.deadband_slider)
        haptic.effect.data.condition.center = slider_to_magnitude(self.center_slider)
        --[[ XXX need a different conversion function here, but I don't have a
          - controller that supports condition effects anyway... :p
          --]]
    else
        self.message_label:set_text("Unknown Effect Type!")
        log_printf("Unknown effect type %d %d\n", devno, _type)
        return
    end

    if not allegro5.al_is_haptic_effect_ok(haptic.haptic, haptic.effect) then
        self.message_label:set_text("Effect Not Supported!")
        log_printf("Playing of effect type %s on %s not supported\n",
            cap_to_name(_type), haptic.name)
        return
    end

    haptic.playing = allegro5.al_upload_and_play_haptic_effect(haptic.haptic,
        haptic.effect, haptic.id, loops)
    if haptic.playing then
        self.message_label:set_text("Playing...")
        log_printf("Started playing %d loops of effect type %s on %s\n",
            loops, cap_to_name(_type), haptic.name)
        self.last_haptic = haptic
    else
        self.message_label:set_text("Playing of effect failed!")
        log_printf("Playing of effect type %s on %s failed\n", cap_to_name(_type),
            haptic.name)
    end

    self.play_button:set_disabled(true)
end

function Prog.on_stop(self)
    local devno = self.device_list:get_cur_value()
    if devno < 0 or devno >= num_haptics then
        log_printf("No such device %d\n", devno)
        return
    end

    local haptic = haptics[devno + INDEX_BASE]
    if haptic.playing and allegro5.al_is_haptic_effect_playing(haptic.id) then
        allegro5.al_stop_haptic_effect(haptic.id)
        haptic.playing = false
        allegro5.al_release_haptic_effect(haptic.id)
        log_printf("Stopped device %d: %s\n", devno, haptic.name)
    end
    self.message_label:set_text("Stopped.")
    self.play_button:set_disabled(false)
end

local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro\n")
    end
    allegro5.al_init_primitives_addon()
    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()
    allegro5.al_install_joystick()
    if not allegro5.al_install_haptic() then
        abort_example("Could not init haptics\n")
    end

    allegro5.al_init_font_addon()
    allegro5.al_init_ttf_addon()

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS)
    local display = allegro5.al_create_display(800, 600)
    if not display then
        abort_example("Unable to create display\n")
    end

    open_log()

    local font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf", 11, 0)
    if not font then
        log_printf("Failed to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf\n")
        font = allegro5.al_create_builtin_font()
        if not font then
            abort_example("Could not create builtin font.\n")
        end
    end


    joystick_queue = allegro5.al_create_event_queue()
    if not joystick_queue then
        abort_example("Could not create joystick event queue font.\n")
    end

    allegro5.al_register_event_source(joystick_queue, allegro5.al_get_joystick_event_source())


    get_all_haptics()

    --[[ Don't remove these braces. --]]
    ; (function()
        --[[ Set up a timer so the display of playback state is polled regularly. --]]
        update_timer = allegro5.al_create_timer(1.0)
        local theme = Theme(font)
        local prog = Prog(theme, display)
        allegro5.al_start_timer(update_timer)
        prog:run()
        prog:__destroy()
        allegro5.al_destroy_timer(update_timer)
    end)()

    release_all_haptics()
    allegro5.al_destroy_event_queue(joystick_queue)

    close_log(false)

    allegro5.al_destroy_font(font)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
