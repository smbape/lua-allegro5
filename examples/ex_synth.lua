#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_synth.cpp
--]]

local cdef = [[
typedef struct ThreadInfo {
    bool saving;
    ALLEGRO_FILE *save_fp;
    ALLEGRO_MIXER *mixer;
    ALLEGRO_MUTEX *mutex;
    ALLEGRO_COND *cond;
    bool stop_requested;
} ThreadInfo;
]]

local cffi_lua_def = [[
    typedef struct ALLEGRO_FILE ALLEGRO_FILE;
    typedef struct ALLEGRO_MIXER ALLEGRO_MIXER;
    typedef struct ALLEGRO_MUTEX ALLEGRO_MUTEX;
    typedef struct ALLEGRO_COND ALLEGRO_COND;
]]


local function mixer_pp_thread_func(arg)
    local allegro5_lua = require("allegro5_lua")
    local allegro5 = allegro5_lua.allegro5

    local ffi = allegro5_lua.ffi

    if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
        allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
        ffi = require("ffi")
    else
        ffi.cdef(cffi_lua_def)
    end

    ffi.cdef(cdef)

    local info = ffi.cast("ThreadInfo*", arg)
    local mixer = info.mixer

    local function mixer_pp_callback(buf, samples, userdata)
        local nch = 0
        local sample_size = 0

        if not info.saving then
            return
        end


        if allegro5.al_get_mixer_channels(mixer) == allegro5.ALLEGRO_CHANNEL_CONF_1 then
            nch = 1
        elseif allegro5.al_get_mixer_channels(mixer) == allegro5.ALLEGRO_CHANNEL_CONF_2 then
            nch = 2
        else
            --[[ Not supported. --]]
            return
        end

        sample_size = allegro5.al_get_audio_depth_size(allegro5.al_get_mixer_depth(mixer))
        allegro5.al_fwrite(info.save_fp, buf, nch * samples * sample_size)
    end

    allegro5.al_set_mixer_postprocess_callback(mixer, mixer_pp_callback, nil)

    allegro5.al_lock_mutex(info.mutex)
    info.stop_requested = false
    while not info.stop_requested do
        allegro5.al_wait_cond(info.cond, info.mutex)
    end

    allegro5.al_set_mixer_postprocess_callback(mixer, nil, nil)
end

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")
local nihgui = require("nihgui")
local lanes = require("lanes")

local env = common.env

local abort_example = common.abort_example
local open_log = common.open_log
local init_platform_specific = common.init_platform_specific
local close_log = common.close_log
local log_printf = common.log_printf
local pointer_as = common.pointer_as
local pointer_cast = common.pointer_cast
local get_stored_pointer = common.get_stored_pointer

local Theme = nihgui.Theme
local Dialog = nihgui.Dialog
local Label = nihgui.Label
local List = nihgui.List
local ToggleButton = nihgui.ToggleButton
local HSlider = nihgui.HSlider

local INDEX_BASE = 1 -- lua is 1-based indexed

local fmod = math.fmod
local sin = math.sin

local ffi = allegro5_lua.ffi

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
    ffi = require("ffi")
else
    ffi.cdef(cffi_lua_def)
    tonumber = ffi.tonumber
end

local intptr_t = function(cdata)
    return tonumber(ffi.cast("intptr_t", ffi.cast("void*", cdata)))
end

ffi.cdef(cdef)

local ThreadInfo = ffi.typeof("ThreadInfo")
local thread_info = ThreadInfo()

--[[
 -    Example program for the Allegro library, by Peter Wang.
 -
 -    Something like the start of a synthesizer.
 --]]

local PI = (allegro5.ALLEGRO_PI)
local TWOPI = (2.0 * PI)
local SAMPLES_PER_BUFFER = (1024)
local STREAM_FREQUENCY = (44100)

local dt = 1.0 / STREAM_FREQUENCY

local Waveform = {
    WAVEFORM_NONE = 0,
    WAVEFORM_SINE = 1,
    WAVEFORM_SQUARE = 2,
    WAVEFORM_TRIANGLE = 3,
    WAVEFORM_SAWTOOTH = 4,
}

--[[ forward declarations --]]
local generate_wave --[[ static void generate_wave(Waveform _type, float *buf, size_t samples, double t,
   float frequency, float phase) --]]
local sine --[[ static void sine(float *buf, size_t samples, double t,
   float frequency, float phase) --]]
local square --[[ static void square(float *buf, size_t samples, double t,
   float frequency, float phase) --]]
local triangle --[[ static void triangle(float *buf, size_t samples, double t,
   float frequency, float phase) --]]
local sawtooth --[[ static void sawtooth(float *buf, size_t samples, double t,
   float frequency, float phase) --]]


--[[ globals --]]
local font_gui
local streams = {}


generate_wave = function(_type, buf, samples, t, frequency, phase)
    if _type == Waveform.WAVEFORM_NONE then
        for i = 0, samples - INDEX_BASE do
            buf[i] = 0.0
        end
    elseif _type == Waveform.WAVEFORM_SINE then
        sine(buf, samples, t, frequency, phase)
    elseif _type == Waveform.WAVEFORM_SQUARE then
        square(buf, samples, t, frequency, phase)
    elseif _type == Waveform.WAVEFORM_TRIANGLE then
        triangle(buf, samples, t, frequency, phase)
    elseif _type == Waveform.WAVEFORM_SAWTOOTH then
        sawtooth(buf, samples, t, frequency, phase)
    end
end


sine = function(buf, samples, t, frequency, phase)
    local w = TWOPI * frequency

    for i = 0, samples - INDEX_BASE do
        local ti = t + i * dt
        buf[i] = sin(w * ti + phase)
    end
end


square = function(buf, samples, t, frequency, phase)
    local w = TWOPI * frequency

    for i = 0, samples - INDEX_BASE do
        local ti = t + i * dt
        local x = sin(w * ti + phase)

        buf[i] = (function() if (x >= 0.0) then return 1.0 else return -1.0 end end)()
    end
end


triangle = function(buf, samples, t, frequency, phase)
    local w = TWOPI * frequency

    for i = 0, samples - INDEX_BASE do
        local tx = w * (t + i * dt) + PI / 2.0 + phase
        local tu = fmod(tx / PI, 2.0)

        if tu <= 1.0 then
            buf[i] = (1.0 - 2.0 * tu)
        else
            buf[i] = (-1.0 + 2.0 * (tu - 1.0))
        end
    end
end


sawtooth = function(buf, samples, t, frequency, phase)
    local w = TWOPI * frequency

    for i = 0, samples - INDEX_BASE do
        local tx = w * (t + i * dt) + PI + phase
        local tu = fmod(tx / PI, 2.0)

        buf[i] = (-1.0 + tu)
    end
end


local Group = common.class({
    __name = "Group",
})


function Group.__init__(self)
    self.list = List()
    self.freq_val_label = Label()
    self.phase_val_label = Label()

    self.freq_label = Label("f")
    self.freq_slider = HSlider(220, 1000)
    self.phase_label = Label("φ")
    self.phase_slider = HSlider(math.floor(100 * PI), math.floor(2 * 100 * PI)) --[[ -π .. π --]]
    self.gain_label = Label("Gain")
    self.gain_slider = HSlider(33, 100) --[[ 0.0 .. 1.0 --]]
    self.pan_label = Label("Pan")
    self.pan_slider = HSlider(100, 200) --[[ -1.0 .. 1.0 --]]
    self.t = 0.0
    self.last_gain = -10000
    self.last_pan = -10000

    --[[ Order must correspond with Waveform. --]]
    self.list:append_item("Off")
    self.list:append_item("Sine")
    self.list:append_item("Square")
    self.list:append_item("Triangle")
    self.list:append_item("Sawtooth")
end

function Group.add_to_dialog(self, d, x, y)
    d:add(self.list, x, y, 4, 4)

    d:add(self.freq_label, x + 4, y, 2, 1)
    d:add(self.freq_slider, x + 6, y, 20, 1)
    d:add(self.freq_val_label, x + 26, y, 4, 1)

    d:add(self.phase_label, x + 4, y + 1, 2, 1)
    d:add(self.phase_slider, x + 6, y + 1, 20, 1)
    d:add(self.phase_val_label, x + 26, y + 1, 4, 1)

    d:add(self.gain_label, x + 4, y + 2, 2, 1)
    d:add(self.gain_slider, x + 6, y + 2, 20, 1)

    d:add(self.pan_label, x + 4, y + 3, 2, 1)
    d:add(self.pan_slider, x + 6, y + 3, 20, 1)
end

function Group.update_labels(self)
    local buf
    local frequency = self:get_frequency()
    local phase = self:get_phase()

    buf = string.format("%4.0f Hz", frequency)
    self.freq_val_label:set_text(buf)

    buf = string.format("%.2f π", phase / PI)
    self.phase_val_label:set_text(buf)
end

function Group.generate(self, buf, samples)
    local _type = self.list:get_cur_value()
    local frequency = self:get_frequency()
    local phase = self:get_phase()

    generate_wave(_type, buf, samples, self.t, frequency, phase)

    self.t = self.t + (dt * samples)
end

function Group.get_frequency(self)
    return self.freq_slider:get_cur_value()
end

function Group.get_phase(self)
    return self.phase_slider:get_cur_value() / 100.0 - PI
end

function Group.get_gain_if_changed(self)
    local gain = self.gain_slider:get_cur_value() / 100.0
    local changed = (self.last_gain ~= gain)
    self.last_gain = gain
    return changed, gain
end

function Group.get_pan_if_changed(self)
    local pan = self.pan_slider:get_cur_value() / 100.0 - 1.0
    local changed = (self.last_pan ~= pan)
    self.last_pan = pan
    return changed, pan
end

local SaveButton = common.class({
    __name = "SaveButton",
}, ToggleButton)


function SaveButton.__init__(self)
    ToggleButton.__init__(self, "Save raw")
end

function SaveButton.on_click(self, arg1, arg2)
    if thread_info.saving then
        log_printf("Stopped saving waveform.\n")
        thread_info.saving = false
        return
    end
    if thread_info.save_fp ~= nil then
        thread_info.save_fp = allegro5.al_fopen("ex_synth.raw", "wb")
    end
    if thread_info.save_fp then
        log_printf("Started saving waveform.\n")
        thread_info.saving = true
    end
end

local Prog = common.class({
    __name = "Prog",
    __destroy = function(self)
        self.d:__destroy()
    end,
})


function Prog.__init__(self, theme, display)
    self.group1 = Group()
    self.group2 = Group()
    self.group3 = Group()
    self.group4 = Group()
    self.group5 = Group()

    self.d = Dialog(theme, display, 30, 26)
    self.save_button = SaveButton()

    self.group1:add_to_dialog(self.d, 1, 1)
    self.group2:add_to_dialog(self.d, 1, 6)
    self.group3:add_to_dialog(self.d, 1, 11)
    self.group4:add_to_dialog(self.d, 1, 16)
    self.group5:add_to_dialog(self.d, 1, 21)
    self.d:add(self.save_button, 27, 25, 3, 1)
end

function Prog.run(self, mixer)
    thread_info.mixer = mixer

    thread_info.mutex = allegro5.al_create_mutex()
    if thread_info.mutex == nil then
        abort_example("Error creating mutex\n")
    end
    thread_info.cond = allegro5.al_create_cond()
    if thread_info.cond == nil then
        abort_example("Error creating cond\n")
    end

    local thread_start = lanes.gen("*", mixer_pp_thread_func)
    local thread = thread_start(intptr_t(thread_info))

    self.d:prepare()

    for _, stream in ipairs(streams) do
        self.d:register_event_source(allegro5.al_get_audio_stream_event_source(stream));
    end
    self.d:set_event_handler(self)

    while not self.d:is_quit_requested() do
        if thread.status == "error" then
            error(thread[1])
        end

        if self.d:is_draw_requested() then
            self.group1:update_labels()
            self.group2:update_labels()
            self.group3:update_labels()
            self.group4:update_labels()
            self.group5:update_labels()

            allegro5.al_clear_to_color(allegro5.al_map_rgb(128, 128, 128))
            self.d:draw()
            allegro5.al_flip_display()
        end

        self.d:run_step(true)
    end

    allegro5.al_lock_mutex(thread_info.mutex)
    thread_info.stop_requested = true
    allegro5.al_broadcast_cond(thread_info.cond)
    allegro5.al_unlock_mutex(thread_info.mutex)
    thread:join()
end

function Prog.handle_event(self, event)
    if event.type == allegro5.ALLEGRO_EVENT_AUDIO_STREAM_FRAGMENT then
        local group

        local stream = pointer_as("ALLEGRO_AUDIO_STREAM", get_stored_pointer(event.any.source))
        local buf = allegro5.al_get_audio_stream_fragment(stream)
        if not buf then
            --[[ This is a normal condition that you must deal with. --]]
            return
        end

        if stream == streams[0 + INDEX_BASE] then
            group = self.group1
        elseif stream == streams[1 + INDEX_BASE] then
            group = self.group2
        elseif stream == streams[2 + INDEX_BASE] then
            group = self.group3
        elseif stream == streams[3 + INDEX_BASE] then
            group = self.group4
        elseif stream == streams[4 + INDEX_BASE] then
            group = self.group5
        else
            group = nil
        end

        -- allegro5.ALLEGRO_ASSERT(group)

        if group then
            local changed, gain, pan
            group:generate(pointer_cast("float", buf), SAMPLES_PER_BUFFER)

            changed, gain = group:get_gain_if_changed()
            if changed then
                allegro5.al_set_audio_stream_gain(stream, gain)
            end

            changed, pan = group:get_pan_if_changed()
            if changed then
                allegro5.al_set_audio_stream_pan(stream, pan)
            end
        end

        if not allegro5.al_set_audio_stream_fragment(stream, buf) then
            log_printf("Error setting stream fragment.\n")
        end
    end
end

local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()

    allegro5.al_init_primitives_addon()
    allegro5.al_init_font_addon()
    allegro5.al_init_ttf_addon()
    init_platform_specific()

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS)
    local display = allegro5.al_create_display(800, 600)
    if not display then
        abort_example("Unable to create display\n")
    end
    allegro5.al_set_window_title(display, "Synthesiser of sorts")

    font_gui = allegro5.al_load_ttf_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf", 12, 0)
    if not font_gui then
        abort_example("Failed to load font\n")
    end

    if not allegro5.al_install_audio() then
        abort_example("Could not init sound!\n")
    end

    if not allegro5.al_reserve_samples(0) then
        abort_example("Could not set up voice and mixer.\n")
    end

    local buffers = 8
    local samples = SAMPLES_PER_BUFFER
    local freq = STREAM_FREQUENCY
    local buf
    local depth = allegro5.ALLEGRO_AUDIO_DEPTH_FLOAT32
    local ch = allegro5.ALLEGRO_CHANNEL_CONF_1
    local mixer = allegro5.al_get_default_mixer()

    for i = 1, 5 do
        streams[i] = allegro5.al_create_audio_stream(buffers, samples, freq, depth, ch)
        if not streams[i] then
            abort_example("Could not create stream.\n")
        end
        while (function()
                buf = allegro5.al_get_audio_stream_fragment(streams[i])
                return buf
            end)() do
            allegro5.al_fill_silence(buf, samples, depth, ch)
            allegro5.al_set_audio_stream_fragment(streams[i], buf)
        end

        if not allegro5.al_attach_audio_stream_to_mixer(streams[i], mixer) then
            abort_example("Could not attach stream to mixer.\n")
        end
    end

    --[[ Prog is destroyed at the end of this scope. --]]
    ; (function()
        local theme = Theme(font_gui)
        local prog = Prog(theme, display)
        prog:run(mixer)
        prog:__destroy()
    end)()

    for _, stream in ipairs(streams) do
        allegro5.al_destroy_audio_stream(stream)
    end
    allegro5.al_uninstall_audio()

    allegro5.al_destroy_font(font_gui)

    allegro5.al_fclose(thread_info.save_fp)

    close_log(false)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
