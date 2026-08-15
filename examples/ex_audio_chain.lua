#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_audio_chain.cpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local rand = common.rand

local INDEX_BASE = 1 -- lua is 1-based indexed

local cos = math.cos
local sin = math.sin
local atan2 = math.atan2 or math.atan ---@diagnostic disable-line: deprecated

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 -    Example program for the Allegro library, by Peter Wang.
 -
 -    Demonstrate the audio addons.
 --]]

local DISP_W = 800
local DISP_H = 600

local function Context()
    return {
        font = nil,
        bg = allegro5.ALLEGRO_COLOR(),
        fg = allegro5.ALLEGRO_COLOR(),
        fill = allegro5.ALLEGRO_COLOR(),
        disabled = allegro5.ALLEGRO_COLOR(),
        highlight = allegro5.ALLEGRO_COLOR(),
    }
end

local Element = common.class({
    __name = "Element",
})

local Voice = common.class({
    __name = "Voice",
}, Element)

local Mixer = common.class({
    __name = "Mixer",
}, Element)

local SampleInstance = common.class({
    __name = "SampleInstance",
}, Element)

local Sample = common.class({
    __name = "Sample",
})

local Audiostream = common.class({
    __name = "Audiostream",
}, Element)

--[[-----------------------------------------------------------------------------]]

local make_path = (function()
    local dir
    local function make_path(str)
        local path

        if not dir then
            dir = allegro5.al_get_standard_path(allegro5.ALLEGRO_RESOURCES_PATH)
            if allegro5.ALLEGRO_MSVC then
               --[[ Hack to cope automatically with MSVC workspaces. --]]
               local last = allegro5.al_get_path_component(dir, -1)
               if last == "Debug"
                  or last == "RelWithDebInfo"
                  or last == "Release"
                  or last == "Profile" then
                  allegro5.al_remove_path_component(dir, -1)
               end
            end
        end

        path = allegro5.al_create_path(str)
        allegro5.al_rebase_path(dir, path)
        return path
    end

    return make_path
end)()

local function basename(filename)
    for i = #filename, 1, -1 do
        local c = filename:sub(i, i)
        if c == "/" or c == "\\" then
            if i == 1 then return c end
            return filename:sub(i + 1, #filename)
        end
    end

    return filename
end

local function clamp(lo, mid, hi)
    if mid < lo then
        return lo
    end
    if mid > hi then
        return hi
    end
    return mid
end

--[[-----------------------------------------------------------------------------]]

function Element.__init__(self)
    self.x = 0
    self.y = 0
    self.w = 40
    self.h = 40
    self.attached_to = nil
end

function Element.set_pos(self, x, y)
    self.x = x
    self.y = y
end

function Element.set_random_pos(self)
    --[[ Could be smarter. --]]
    self.x = rand() % (DISP_W - self.w)
    self.y = rand() % (DISP_H - self.h)
end

function Element.attach(self, elt)
    local rc = elt ~= nil and self:do_attach(elt)

    if rc then
        elt:set_attached_to(self)
    end

    return rc
end

function Element.do_attach(self, elt)
    return false
end

function Element.detach(self)
    local rc = self.attached_to and self:do_detach()
    if rc then
        self.attached_to = nil
    end
    return rc
end

function Element.set_attached_to(self, attached_to)
    self.attached_to = attached_to
end

function Element.is_attached_to(self, elt)
    return self.attached_to == elt
end

function Element.draw(self, ctx, highlight)
    if self.attached_to then
        local x2, y2 = self.attached_to:input_point()
        self:draw_arrow(ctx, x2, y2, highlight)
    end

    local textcol = ctx.fg
    local boxcol = ctx.fg
    if highlight then
        boxcol = ctx.highlight
    end
    if not self:is_playing() then
        textcol = ctx.disabled
    end

    local rad = 7.0
    allegro5.al_draw_filled_rounded_rectangle(self.x + 0.5, self.y + 0.5, self.x + self.w - 0.5, self.y + self.h - 0.5,
        rad, rad, ctx.fill)
    allegro5.al_draw_rounded_rectangle(self.x + 0.5, self.y + 0.5, self.x + self.w - 0.5, self.y + self.h - 0.5, rad, rad,
        boxcol, 1.0)

    local th = allegro5.al_get_font_line_height(ctx.font)
    allegro5.al_draw_text(ctx.font, textcol, self.x + math.floor(self.w / 2), self.y + math.floor(self.h / 2) - th / 2,
        allegro5.ALLEGRO_ALIGN_CENTRE, self:get_label())

    local gain = self:get_gain()
    if gain > 0.0 then
        local igain = 1.0 - clamp(0.0, gain, 2.0) / 2.0
        allegro5.al_draw_rectangle(self.x + self.w + 1.5, self.y + self.h * igain, self.x + self.w + 3.5, self.y + self
            .h, ctx.fg, 1.0)
    end
end

function Element.draw_arrow(self, ctx, x2, y2, highlight)
    local col = allegro5.ALLEGRO_COLOR()
    local x1, y1 = self:output_point()
    col = ((function() if highlight then return ctx.highlight else return ctx.fg end end)())
    allegro5.al_draw_line(x1, y1, x2, y2, col, 1.0)

    local a = atan2(y1 - y2, x1 - x2)
    local a1 = a + 0.5
    local a2 = a - 0.5
    local len = 7.0
    allegro5.al_draw_line(x2, y2, x2 + len * cos(a1), y2 + len * sin(a1), col, 1.0)
    allegro5.al_draw_line(x2, y2, x2 + len * cos(a2), y2 + len * sin(a2), col, 1.0)
end

function Element.move_by(self, dx, dy)
    self.x = self.x + dx
    self.y = self.y + dy

    if self.x < 0 then
        self.x = 0
    end
    if self.y < 0 then
        self.y = 0
    end
    if self.x + self.w > DISP_W then
        self.x = DISP_W - self.w
    end
    if self.y + self.h > DISP_H then
        self.y = DISP_H - self.h
    end
end

function Element.contains(self, px, py)
    return px >= self.x and px < self.x + self.w
        and py >= self.y and py < self.y + self.h
end

function Element.output_point(self)
    local ox = self.x + math.floor(self.w / 2)
    local oy = self.y
    return ox, oy
end

function Element.input_point(self)
    local ox = self.x + math.floor(self.w / 2)
    local oy = self.y + self.h
    return ox, oy
end

--[[-----------------------------------------------------------------------------]]

function Voice.__init__(self)
    Element.__init__(self)
    self:set_random_pos()
    self.voice = allegro5.al_create_voice(44100, allegro5.ALLEGRO_AUDIO_DEPTH_INT16,
        allegro5.ALLEGRO_CHANNEL_CONF_2)
end

function Voice.__destroy(self)
    allegro5.al_destroy_voice(self.voice)
end

function Voice.valid(self)
    return self.voice ~= nil
end

function Voice.do_attach(self, elt)
    if elt:__instanceof(Mixer) then
        local mixer = elt.mixer
        return allegro5.al_attach_mixer_to_voice(mixer, self.voice)
    end

    if elt:__instanceof(SampleInstance) then
        local spl = elt.splinst
        return allegro5.al_attach_sample_instance_to_voice(spl, self.voice)
    end

    if elt:__instanceof(Audiostream) then
        local stream = elt.stream
        return allegro5.al_attach_audio_stream_to_voice(stream, self.voice)
    end

    return false
end

function Voice.do_detach(self)
    return false
end

function Voice.is_playing(self)
    return allegro5.al_get_voice_playing(self.voice)
end

function Voice.toggle_playing(self)
    local playing = allegro5.al_get_voice_playing(self.voice)
    return allegro5.al_set_voice_playing(self.voice, not playing)
end

function Voice.get_gain(self)
    return 0.0
end

function Voice.adjust_gain(self, d)
    return false
end

function Voice.get_label(self)
    return "Voice"
end

--[[-----------------------------------------------------------------------------]]

function Mixer.__init__(self)
    Element.__init__(self)
    self:set_random_pos()
    self.mixer = allegro5.al_create_mixer(44100, allegro5.ALLEGRO_AUDIO_DEPTH_FLOAT32,
        allegro5.ALLEGRO_CHANNEL_CONF_2)
end

function Mixer.__destroy(self)
    allegro5.al_destroy_mixer(self.mixer)
end

function Mixer.do_attach(self, elt)
    if elt:__instanceof(Mixer) then
        local mixer = elt.mixer
        return allegro5.al_attach_mixer_to_mixer(mixer, self.mixer)
    end

    if elt:__instanceof(SampleInstance) then
        local spl = elt.splinst
        return allegro5.al_attach_sample_instance_to_mixer(spl, self.mixer)
    end

    if elt:__instanceof(Audiostream) then
        local stream = elt.stream
        return allegro5.al_attach_audio_stream_to_mixer(stream, self.mixer)
    end

    return false
end

function Mixer.do_detach(self)
    return allegro5.al_detach_mixer(self.mixer)
end

function Mixer.is_playing(self)
    return allegro5.al_get_mixer_playing(self.mixer)
end

function Mixer.toggle_playing(self)
    local playing = allegro5.al_get_mixer_playing(self.mixer)
    return allegro5.al_set_mixer_playing(self.mixer, not playing)
end

function Mixer.get_gain(self)
    return allegro5.al_get_mixer_gain(self.mixer)
end

function Mixer.adjust_gain(self, d)
    local gain = allegro5.al_get_mixer_gain(self.mixer) + d
    gain = clamp(0, gain, 2)
    return allegro5.al_set_mixer_gain(self.mixer, gain)
end

function Mixer.get_label(self)
    return "Mixer"
end

--[[-----------------------------------------------------------------------------]]

function SampleInstance.__init__(self)
    Element.__init__(self)
    self.spl = nil
    self.pos = 0
    self.w = 150
    self:set_random_pos()
    self.splinst = allegro5.al_create_sample_instance(nil)
end

function SampleInstance.__destroy(self)
    allegro5.al_destroy_sample_instance(self.splinst)
end

function SampleInstance.do_detach(self)
    return allegro5.al_detach_sample_instance(self.splinst)
end

function SampleInstance.is_playing(self)
    return allegro5.al_get_sample_instance_playing(self.splinst)
end

function SampleInstance.toggle_playing(self)
    local playing = self:is_playing()
    if playing then
        self.pos = allegro5.al_get_sample_instance_position(self.splinst)
    else
        allegro5.al_set_sample_instance_position(self.splinst, self.pos)
    end
    return allegro5.al_set_sample_instance_playing(self.splinst, not playing)
end

function SampleInstance.get_gain(self)
    return allegro5.al_get_sample_instance_gain(self.splinst)
end

function SampleInstance.adjust_gain(self, d)
    local gain = allegro5.al_get_sample_instance_gain(self.splinst) + d
    gain = clamp(0, gain, 2)
    return allegro5.al_set_sample_instance_gain(self.splinst, gain)
end

function SampleInstance.set_sample(self, spl)
    local playing = self:is_playing()
    local rc = allegro5.al_set_sample(self.splinst, spl.spl)
    if rc then
        self.spl = spl
        allegro5.al_set_sample_instance_playmode(self.splinst, allegro5.ALLEGRO_PLAYMODE_LOOP)
        allegro5.al_set_sample_instance_playing(self.splinst, playing)
    end
    return rc
end

function SampleInstance.get_label(self)
    if self.spl then
        return self.spl:get_filename()
    end
    return "No sample"
end

--[[-----------------------------------------------------------------------------]]

function Sample.__init__(self, filename)
    self.spl = allegro5.al_load_sample(filename)
    self.filename = basename(filename)
end

function Sample.__destroy(self)
    allegro5.al_destroy_sample(self.spl)
end

function Sample.valid(self)
    return self.spl ~= nil
end

function Sample.get_filename(self)
    return self.filename
end

--[[-----------------------------------------------------------------------------]]

function Audiostream.__init__(self, filename)
    Element.__init__(self)
    self.w = 150
    self:set_random_pos()
    self.filename = basename(filename)

    self.stream = allegro5.al_load_audio_stream(filename, 4, 2048)
    if self.stream then
        allegro5.al_set_audio_stream_playmode(self.stream, allegro5.ALLEGRO_PLAYMODE_LOOP)
    end
end

function Audiostream.__destroy(self)
    allegro5.al_destroy_audio_stream(self.stream)
end

function Audiostream.valid(self)
    return self.stream
end

function Audiostream.do_detach(self)
    return allegro5.al_detach_audio_stream(self.stream)
end

function Audiostream.is_playing(self)
    return allegro5.al_get_audio_stream_playing(self.stream)
end

function Audiostream.toggle_playing(self)
    local playing = allegro5.al_get_audio_stream_playing(self.stream)
    return allegro5.al_set_audio_stream_playing(self.stream, not playing)
end

function Audiostream.get_gain(self)
    return allegro5.al_get_audio_stream_gain(self.stream)
end

function Audiostream.adjust_gain(self, d)
    local gain = allegro5.al_get_audio_stream_gain(self.stream) + d
    gain = clamp(0, gain, 2)
    return allegro5.al_set_audio_stream_gain(self.stream, gain)
end

function Audiostream.get_label(self)
    return self.filename
end

--[[-----------------------------------------------------------------------------]]

local Prog = common.class({
    __name = "Prog",
    __destroy = function(self)
        for _, element in ipairs(self.elements) do
            element:__destroy()
        end
    end
})

function Prog.__init__(self)
    self.dpy = nil
    self.queue = nil
    self.ctx = Context()
    self.samples = {}
    self.stream_paths = {}
    self.elements = {}
    self.cur_button = 0
    self.cur_element = nil
    self.connect_x = 0
    self.connect_y = 0
end

function Prog.init(self)
    if not allegro5.al_init() then
        abort_example("Could not initialise Allegro.\n")
    end
    if not allegro5.al_init_primitives_addon() then
        abort_example("Could not initialise primitives.\n")
    end
    allegro5.al_init_font_addon()
    if not allegro5.al_init_ttf_addon() then
        abort_example("Could not initialise TTF fonts.\n")
    end
    if not allegro5.al_install_audio() then
        abort_example("Could not initialise audio.\n")
    end
    if not allegro5.al_init_acodec_addon() then
        abort_example("Could not initialise audio codecs.\n")
    end
    init_platform_specific()

    self.dpy = allegro5.al_create_display(800, 600)
    if not self.dpy then
        abort_example("Could not create display.\n")
    end
    if not allegro5.al_install_keyboard() then
        abort_example("Could not install keyboard.\n")
    end
    if not allegro5.al_install_mouse() then
        abort_example("Could not install mouse.\n")
    end

    self.ctx.font = allegro5.al_load_ttf_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf", 10, 0)
    if not self.ctx.font then
        abort_example("Could not load font.\n")
    end
    self.ctx.bg = allegro5.al_map_rgb_f(0.9, 0.9, 0.9)
    self.ctx.fg = allegro5.al_map_rgb_f(0, 0, 0)
    self.ctx.fill = allegro5.al_map_rgb_f(0.85, 0.85, 0.85)
    self.ctx.disabled = allegro5.al_map_rgb_f(0.6, 0.6, 0.6)
    self.ctx.highlight = allegro5.al_map_rgb_f(1, 0.1, 0.1)

    self.queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(self.queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(self.queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(self.queue, allegro5.al_get_display_event_source(self.dpy))
end

function Prog.add_sample(self, filename)
    local path = make_path(filename)
    local spl = Sample(allegro5.al_path_cstr(path, '/'))
    if spl then
        self.samples[#self.samples + 1] = spl
    else
        spl:__destroy()
    end
    allegro5.al_destroy_path(path)
end

function Prog.add_stream_path(self, filename)
    local path = make_path(filename)
    self.stream_paths[#self.stream_paths + 1] = allegro5.al_path_cstr(path, '/')
    allegro5.al_destroy_path(path)
end

function Prog.initial_config(self)
    local voice = self:new_voice()
    if voice == nil then
        abort_example("Could not create initial voice.\n")
    end
    voice:set_pos(300, 50)

    local mixer = self:new_mixer()
    mixer:set_pos(300, 150)
    voice:attach(mixer)

    local splinst = self:new_sample_instance()
    splinst:set_pos(220, 300)
    mixer:attach(splinst)
    splinst:toggle_playing()

    local splinst2 = self:new_sample_instance()
    splinst2:set_pos(120, 240)
    mixer:attach(splinst2)
    splinst2:toggle_playing()

    local mixer2 = self:new_mixer()
    mixer2:set_pos(500, 250)
    mixer:attach(mixer2)

    local stream = self:new_audiostream()
    if stream then
        stream:set_pos(450, 350)
        mixer2:attach(stream)
    end
end

function Prog.new_voice(self)
    local voice = Voice()
    if voice:valid() then
        self.elements[#self.elements + 1] = voice
    else
        voice:__destroy()
        voice = nil
    end
    return voice
end

function Prog.new_mixer(self)
    local mixer = Mixer()
    self.elements[#self.elements + 1] = mixer
    return mixer
end

; (function()
    local i = 0
    function Prog.new_sample_instance(self)
        local splinst = SampleInstance()
        if #self.samples > 0 then
            local n = i % #self.samples
            i = i + 1
            splinst:set_sample(self.samples[n + INDEX_BASE])
            i = i + 1
        end
        self.elements[#self.elements + 1] = splinst
        return splinst
    end
end)()

; (function()
    local i = 0
    function Prog.new_audiostream(self)
        if #self.stream_paths > 0 then
            local n = i % #self.stream_paths
            i = i + 1
            local stream = Audiostream(self.stream_paths[n + INDEX_BASE])
            if stream:valid() then
                self.elements[#self.elements + 1] = stream
                return stream
            end
            stream:__destroy()
        end
        return nil
    end
end)()

function Prog.run(self)
    while true do
        if allegro5.al_is_event_queue_empty(self.queue) then
            self:redraw()
        end

        local ev = allegro5.ALLEGRO_EVENT()
        allegro5.al_wait_for_event(self.queue, ev)

        if ev.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            return
        elseif ev.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
            self:process_mouse_button_down(ev.mouse.button, ev.mouse.x, ev.mouse.y)
        elseif ev.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_UP then
            self:process_mouse_button_up(ev.mouse.button, ev.mouse.x, ev.mouse.y)
        elseif ev.type == allegro5.ALLEGRO_EVENT_MOUSE_AXES then
            if ev.mouse.dz ~= 0 then
                self:process_mouse_wheel(ev.mouse.dz)
            else
                self:process_mouse_axes(ev.mouse.x, ev.mouse.y,
                    ev.mouse.dx, ev.mouse.dy)
            end
        elseif ev.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if ev.keyboard.unichar == 27 then
                return
            end
            self:process_key_char(ev.keyboard.unichar)
        end
    end
end

function Prog.process_mouse_button_down(self, mb, mx, my)
    if self.cur_button == 0 then
        self.cur_element = self:find_element(mx, my)
        if self.cur_element then
            self.cur_button = mb
        end
        if self.cur_button == 2 then
            self.connect_x = mx
            self.connect_y = my
        end
    end
end

function Prog.process_mouse_button_up(self, mb, mx, my)
    if mb ~= self.cur_button then
        return
    end

    if self.cur_button == 2 and self.cur_element then
        local sink = self:find_element(mx, my)
        self.cur_element:detach()
        if sink and sink ~= self.cur_element then
            sink:attach(self.cur_element)
        end
        self.cur_element = nil
    end

    self.cur_button = 0
end

function Prog.process_mouse_axes(self, mx, my, dx, dy)
    if self.cur_button == 1 and self.cur_element then
        self.cur_element:move_by(dx, dy)
    end
    if self.cur_button == 2 and self.cur_element then
        self.connect_x = mx
        self.connect_y = my
    end
end

function Prog.process_mouse_wheel(self, dz)
    if self.cur_element then
        self.cur_element:adjust_gain(dz * 0.1)
    end
end

function Prog.process_key_char(self, unichar)
    local upper = string.byte(string.upper(string.char(unichar)))
    if upper == string.byte('V') then
        self:new_voice()
    elseif upper == string.byte('M') then
        self:new_mixer()
    elseif upper == string.byte('S') then
        self:new_sample_instance()
    elseif upper == string.byte('A') then
        self:new_audiostream()
    elseif upper == string.byte(' ') then
        if self.cur_element then
            self.cur_element:toggle_playing()
        end
    elseif upper == string.byte('X') then
        if self.cur_element then
            self:delete_element(self.cur_element)
            self.cur_element = nil
        end
    elseif upper >= string.byte('1') and upper <= string.byte('9') then
        local n = upper - string.byte('1')
        if n < #self.samples and self.cur_element and self.cur_element:__instanceof(SampleInstance) then
            local splinst = self.cur_element
            splinst:set_sample(self.samples[n + INDEX_BASE])
        end
    end
end

function Prog.find_element(self, x, y)
    for i = 0, #self.elements - INDEX_BASE do
        if self.elements[i + INDEX_BASE]:contains(x, y) then
            return self.elements[i + INDEX_BASE]
        end
    end
    return nil
end

function Prog.delete_element(self, elt)
    for i = 1, #self.elements do
        local it = self.elements[i]
        if it:is_attached_to(elt) then
            it:detach()
        end
    end
    for i = 1, #self.elements do
        local it = self.elements[i]
        if it == elt then
            it:detach()
            it:__destroy()
            for j = i + 1, #self.elements do
                self.elements[j - 1] = self.elements[j]
            end
            table.remove(self.elements)
            break
        end
    end
end

function Prog.redraw(self)
    allegro5.al_clear_to_color(self.ctx.bg)

    for i = 1, #self.elements do
        local it = self.elements[i]
        local highlight = (it == self.cur_element)
        it:draw(self.ctx, highlight)

        if highlight and self.cur_button == 2 then
            it:draw_arrow(self.ctx, self.connect_x, self.connect_y, highlight)
        end
    end

    local y = allegro5.al_get_display_height(self.dpy)
    local th = allegro5.al_get_font_line_height(self.ctx.font)
    allegro5.al_draw_textf(self.ctx.font, self.ctx.fg, 0, y - th * 2, allegro5.ALLEGRO_ALIGN_LEFT,
        "Create [v]oices, [m]ixers, [s]ample instances, [a]udiostreams.   "
        .. "[SPACE] pause playback.    "
        .. "[1]-[9] set sample.    "
        .. "[x] delete.")
    allegro5.al_draw_textf(self.ctx.font, self.ctx.fg, 0, y - th * 1, allegro5.ALLEGRO_ALIGN_LEFT,
        "Mouse: [LMB] select element.   "
        .. "[RMB] attach sources to sinks "
        .. "(sample->mixer, mixer->mixer, mixer->voice, sample->voice)")

    allegro5.al_flip_display()
end

local function main()
    local prog = Prog()
    prog:init()
    prog:add_sample(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/air_0.ogg")
    prog:add_sample(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/air_1.ogg")
    prog:add_sample(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/earth_0.ogg")
    prog:add_sample(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/earth_1.ogg")
    prog:add_sample(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/earth_2.ogg")
    prog:add_sample(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/fire_0.ogg")
    prog:add_sample(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/fire_1.ogg")
    prog:add_sample(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/water_0.ogg")
    prog:add_sample(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/water_1.ogg")
    prog:add_stream_path(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/../../demos/cosmic_protector/data/sfx/game_music.ogg")
    prog:add_stream_path(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/../../demos/cosmic_protector/data/sfx/title_music.ogg")
    prog:initial_config()
    prog:run()
    prog:__destroy()

    --[[ Let Allegro handle the cleanup. --]]
    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
