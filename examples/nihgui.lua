local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/nihgui.hpp
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/nihgui.cpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local INDEX_BASE = 1 -- lua is 1-based indexed

local c_string = allegro5_lua.std.string

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    c_string = ffi.string
end

local function CLAMP(x, y, z)
    return math.max(x, math.min(y, z))
end

local SaveState = common.class({
    __name = "SaveState",

    __init__ = function(self, save)
        if save == nil then save = allegro5.ALLEGRO_STATE_ALL end
        self.state = allegro5.ALLEGRO_STATE()
        allegro5.al_store_state(self.state, save)
    end,

    __destroy = function(self)
        allegro5.al_restore_state(self.state)
    end
})

local UString = common.class({
    __name = "UString",

    __init__ = function(self, s, first, end_)
        self.info = allegro5.ALLEGRO_USTR_INFO()
        if end_ == nil then end_ = -1 end
        if end_ == -1 then
            end_ = allegro5.al_ustr_size(s)
        end
        self.ustr = allegro5.al_ref_ustr(self.info, s, first, end_)
    end,

    -- Conversion
    toustr = function(self)
        return self.ustr
    end,
})

exports.Theme = common.class({
    __name = "Theme",

    __init__ = function(self, font)
        self.bg = allegro5.al_map_rgb(255, 255, 255)
        self.fg = allegro5.al_map_rgb(0, 0, 0)
        self.highlight = allegro5.al_map_rgb(128, 128, 255)
        self.font = font
    end
})

exports.Widget = common.class({
    __name = "Widget",

    __init__ = function(self)
        -- private
        self.grid_x = 0
        self.grid_y = 0
        self.grid_w = 0
        self.grid_h = 0

        -- protected
        self.dialog = nil
        self.x1 = 0
        self.y1 = 0
        self.x2 = 0
        self.y2 = 0
        self.disabled = false
    end,

    configure = function(self, xsize, ysize, x_padding, y_padding)
        self.x1 = xsize * self.grid_x + x_padding
        self.y1 = ysize * self.grid_y + y_padding
        self.x2 = xsize * (self.grid_x + self.grid_w) - x_padding - 1
        self.y2 = ysize * (self.grid_y + self.grid_h) - y_padding - 1
    end,

    contains = function(self, x, y)
        return (x >= self.x1 and y >= self.y1 and x <= self.x2 and y <= self.y2)
    end,

    width = function(self)
        return self.x2 - self.x1 + 1
    end,

    height = function(self)
        return self.y2 - self.y1 + 1
    end,

    want_mouse_focus = function(self)
        return true
    end,

    got_mouse_focus = function(self) end,
    lost_mouse_focus = function(self) end,
    on_mouse_button_down = function(self, mx, my) end,
    on_mouse_button_hold = function(self, mx, my) end,
    on_mouse_button_up = function(self, mx, my) end,
    on_click = function(self, mx, my) end,

    want_key_focus = function()
        return false
    end,
    got_key_focus = function(self) end,
    lost_key_focus = function(self) end,
    on_key_down = function(self, event) end,

    draw = function(self)
        error("draw must be implemented")
    end,
    set_disabled = function(self, value)
        self.disabled = value
    end,
    is_disabled = function(self)
        return self.disabled
    end,
})

exports.EventHandler = common.class({
    __name = "EventHandler",

    handle_event = function(self, event)
        error("handle_event must be implemented")
    end
})

exports.Dialog = common.class({
    __name = "Dialog",

    __init__ = function(self, theme, display, grid_m, grid_n)
        self.theme = theme
        self.display = display
        self.grid_m = grid_m
        self.grid_n = grid_n
        self.x_padding = 1
        self.y_padding = 1

        self.draw_requested = true
        self.quit_requested = false

        self.all_widgets = {}
        self.mouse_over_widget = nil
        self.mouse_down_widget = nil
        self.key_widget = nil

        self.event_handler = nil

        self.event_queue = allegro5.al_create_event_queue()
        allegro5.al_register_event_source(self.event_queue, allegro5.al_get_keyboard_event_source())
        allegro5.al_register_event_source(self.event_queue, allegro5.al_get_mouse_event_source())
        allegro5.al_register_event_source(self.event_queue, allegro5.al_get_display_event_source(display))
        if allegro5.al_is_touch_input_installed() then
            allegro5.al_register_event_source(self.event_queue,
                allegro5.al_get_touch_input_mouse_emulation_event_source())
        end
    end,

    __destroy = function(self)
        self.display = nil
        allegro5.al_destroy_event_queue(self.event_queue)
        self.event_queue = nil
    end,

    set_padding = function(self, x_padding, y_padding)
        self.x_padding = x_padding
        self.y_padding = y_padding
    end,

    add = function(self, widget, grid_x, grid_y, grid_w, grid_h)
        widget.grid_x = grid_x
        widget.grid_y = grid_y
        widget.grid_w = grid_w
        widget.grid_h = grid_h

        self.all_widgets[#self.all_widgets + 1] = widget
        widget.dialog = self
    end,

    prepare = function(self)
        self:configure_all()

        --[[ XXX this isn't working right in X.  The mouse position is reported as
        - (0,0) initially, until the mouse pointer is moved.
        --]]
        local mst = allegro5.ALLEGRO_MOUSE_STATE()
        allegro5.al_get_mouse_state(mst)
        self:check_mouse_over(mst.x, mst.y)
    end,

    run_step = function(self, block)
        local event = allegro5.ALLEGRO_EVENT()

        if block then
            allegro5.al_wait_for_event(self.event_queue, nil)
        end

        while allegro5.al_get_next_event(self.event_queue, event) do
            if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
                self:request_quit()
            elseif event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
                self:on_key_down(event.keyboard)
            elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_AXES then
                self:on_mouse_axes(event.mouse)
            elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
                self:on_mouse_button_down(event.mouse)
            elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_UP then
                self:on_mouse_button_up(event.mouse)
            elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_EXPOSE then
                self:request_draw()
            else
                if self.event_handler then
                    self.event_handler:handle_event(event)
                end
            end
        end
    end,

    request_quit = function(self)
        self.quit_requested = true
    end,

    is_quit_requested = function(self)
        return self.quit_requested
    end,

    request_draw = function(self)
        self.draw_requested = true
    end,

    is_draw_requested = function(self)
        return self.draw_requested
    end,

    draw = function(self)
        local cx, cy, cw, ch = allegro5.al_get_clipping_rectangle()

        for _, wid in ipairs(self.all_widgets) do
            allegro5.al_set_clipping_rectangle(wid.x1, wid.y1, wid:width(), wid:height())
            wid:draw()
        end

        allegro5.al_set_clipping_rectangle(cx, cy, cw, ch)

        self.draw_requested = false
    end,

    get_theme = function(self)
        return self.theme
    end,


    register_event_source = function(self, source)
        allegro5.al_register_event_source(self.event_queue, source)
    end,

    set_event_handler = function(self, event_handler)
        self.event_handler = event_handler
    end,

    -- private
    configure_all = function(self)
        local xsize = math.floor(allegro5.al_get_display_width(self.display) / self.grid_m)
        local ysize = math.floor(allegro5.al_get_display_height(self.display) / self.grid_n)

        for _, wid in ipairs(self.all_widgets) do
            wid:configure(xsize, ysize, self.x_padding, self.y_padding)
        end
    end,

    on_key_down = function(self, event)
        if event.display ~= self.display then
            return
        end

        -- XXX think of something better when we need it
        if event.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
            self:request_quit()
        end

        if self.key_widget then
            self.key_widget:on_key_down(event)
        end
    end,

    on_mouse_axes = function(self, event)
        local mx = event.x
        local my = event.y

        if event.display ~= self.display then
            return
        end

        if self.mouse_down_widget then
            self.mouse_down_widget:on_mouse_button_hold(mx, my)
            return
        end

        self:check_mouse_over(mx, my)
    end,

    check_mouse_over = function(self, mx, my)
        if self.mouse_over_widget and self.mouse_over_widget:contains(mx, my) then
            --[[ no change --]]
            return
        end

        for _, wid in ipairs(self.all_widgets) do
            if wid:contains(mx, my) and wid:want_mouse_focus() then
                self.mouse_over_widget = wid
                self.mouse_over_widget:got_mouse_focus()
                return
            end
        end

        if self.mouse_over_widget then
            self.mouse_over_widget:lost_mouse_focus()
            self.mouse_over_widget = nil
        end
    end,

    on_mouse_button_down = function(self, event)
        if event.button ~= 1 then
            return
        end

        --[[ With touch input we may not receive mouse axes event before the touch
        - so we must check which widget the touch is over.
        --]]
        self:check_mouse_over(event.x, event.y)
        if not self.mouse_over_widget then
            if self.key_widget then
                self.key_widget:lost_key_focus()
                self.key_widget = nil
            end
            return
        end

        self.mouse_down_widget = self.mouse_over_widget
        self.mouse_down_widget:on_mouse_button_down(event.x, event.y)

        --[[ transfer key focus --]]
        if self.mouse_down_widget ~= self.key_widget then
            if self.key_widget then
                self.key_widget:lost_key_focus()
                self.key_widget = nil
            end
            if self.mouse_down_widget:want_key_focus() then
                self.key_widget = self.mouse_down_widget
                self.key_widget:got_key_focus()
            end
        end
    end,

    on_mouse_button_up = function(self, event)
        if event.button ~= 1 then
            return
        end
        if not self.mouse_down_widget then
            return
        end

        self.mouse_down_widget:on_mouse_button_up(event.x, event.y)
        if self.mouse_down_widget:contains(event.x, event.y) then
            self.mouse_down_widget:on_click(event.x, event.y)
        end
        self.mouse_down_widget = nil
    end,
})

exports.Label = common.class({
    __name = "Label",

    __init__ = function(self, text, centred)
        if text == nil then text = "" end
        if centred == nil then centred = true end

        exports.Widget.__init__(self)
        self.text = text
        self.centred = centred
    end,

    draw = function(self)
        local theme = self.dialog:get_theme()
        local state = SaveState()
        local fg = theme.fg

        if self:is_disabled() then
            fg = allegro5.al_map_rgb(64, 64, 64)
        end

        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
        if self.centred then
            allegro5.al_draw_text(theme.font, fg, math.floor((self.x1 + self.x2 + 1) / 2),
                self.y1, allegro5.ALLEGRO_ALIGN_CENTRE, self.text)
        else
            allegro5.al_draw_text(theme.font, fg, self.x1, self.y1, 0, self.text)
        end

        state:__destroy()
    end,

    set_text = function(self, new_text)
        self.text = new_text
    end,

    want_mouse_focus = function(self)
        return false
    end

}, exports.Widget)

exports.Button = common.class({
    __name = "Button",

    __init__ = function(self, text)
        exports.Widget.__init__(self)
        self.text = text
        self.pushed = false
    end,

    on_mouse_button_down = function(self, mx, my)
        if self:is_disabled() then
            return
        end

        self.pushed = true
        self.dialog:request_draw()
    end,

    on_mouse_button_up = function(self, mx, my)
        if self:is_disabled() then
            return
        end

        self.pushed = false
        self.dialog:request_draw()
    end,

    draw = function(self)
        local theme = self.dialog:get_theme()
        local fg
        local bg
        local state = SaveState()
        local y = 0

        if self.pushed then
            fg = theme.bg
            bg = theme.fg
        else
            fg = theme.fg
            bg = theme.bg
        end

        if self:is_disabled() then
            bg = allegro5.al_map_rgb(64, 64, 64)
        end

        allegro5.al_draw_filled_rectangle(self.x1, self.y1,
            self.x2, self.y2, bg)
        allegro5.al_draw_rectangle(self.x1 + 0.5, self.y1 + 0.5,
            self.x2 - 0.5, self.y2 - 0.5, fg, 0)
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)

        --[[ Center the text vertically in the button, taking the font size
        - into consideration.
        --]]
        y = math.floor((self.y1 + self.y2 - allegro5.al_get_font_line_height(theme.font) - 1) / 2)

        allegro5.al_draw_text(theme.font, fg, math.floor((self.x1 + self.x2 + 1) / 2),
            y, allegro5.ALLEGRO_ALIGN_CENTRE, self.text)

        state:__destroy()
    end,

    get_pushed = function(self)
        return self.pushed
    end,
}, exports.Widget)

exports.ToggleButton = common.class({
    __name = "ToggleButton",

    __init__ = function(self, text)
        exports.Button.__init__(self, text)
    end,

    on_mouse_button_down = function(self, mx, my)
        if self:is_disabled() then
            return
        end

        self:set_pushed(not self.pushed)
    end,

    on_mouse_button_up = function(self, mx, my)
        if self:is_disabled() then
            return
        end
    end,

    set_pushed = function(self, pushed)
        if self.pushed ~= pushed then
            self.pushed = pushed
            if self.dialog then
                self.dialog:request_draw()
            end
        end
    end,
}, exports.Button)

exports.List = common.class({
    __name = "List",

    __init__ = function(self, initial_selection)
        if initial_selection == nil then initial_selection = 0 end

        exports.Widget.__init__(self)
        self.items = {}
        self.selected_item = initial_selection
    end,

    want_key_focus = function(self)
        return not self:is_disabled()
    end,

    on_key_down = function(self, event)
        if self:is_disabled() then
            return
        end


        if event.keycode == allegro5.ALLEGRO_KEY_DOWN then
            if self.selected_item < #self.items - 1 then
                self.selected_item = self.selected_item + 1
                self.dialog:request_draw()
            end
        elseif event.keycode == allegro5.ALLEGRO_KEY_UP then
            if self.selected_item > 0 then
                self.selected_item = self.selected_item - 1
                self.dialog:request_draw()
            end
        end
    end,

    on_click = function(self, mx, my)
        if self:is_disabled() then
            return
        end

        local theme = self.dialog:get_theme()
        local i = math.floor((my - self.y1) / allegro5.al_get_font_line_height(theme.font))
        if i < #self.items then
            self.selected_item = i
            self.dialog:request_draw()
        end
    end,

    draw = function(self)
        local theme = self.dialog:get_theme()
        local state = SaveState()
        local bg = theme.bg

        if self:is_disabled() then
            bg = allegro5.al_map_rgb(64, 64, 64)
        end

        allegro5.al_draw_filled_rectangle(self.x1 + 1, self.y1 + 1, self.x2 - 1, self.y2 - 1, bg)

        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
        local font_height = allegro5.al_get_font_line_height(theme.font)
        for i = 0, #self.items - INDEX_BASE do
            local yi = self.y1 + i * font_height

            if i == self.selected_item then
                allegro5.al_draw_filled_rectangle(self.x1 + 1, yi, self.x2 - 1, yi + font_height - 1,
                    theme.highlight)
            end

            allegro5.al_draw_text(theme.font, theme.fg, self.x1, yi, 0, self.items[i + INDEX_BASE])
        end

        state:__destroy()
    end,

    clear_items = function(self)
        self.items = {}
        self.selected_item = 0
    end,

    append_item = function(self, text)
        self.items[#self.items + 1] = text
    end,

    get_selected_item_text = function(self)
        if self.selected_item < #self.items then
            return self.items[self.selected_item + INDEX_BASE]
        else
            return "" -- empty_string
        end
    end,

    get_cur_value = function(self)
        return self.selected_item
    end

}, exports.Widget)

exports.VSlider = common.class({
    __name = "VSlider",

    __init__ = function(self, cur_value, max_value)
        if cur_value == nil then cur_value = 0 end
        if max_value == nil then max_value = 1 end

        exports.Widget.__init__(self)
        self.cur_value = cur_value
        self.max_value = max_value
    end,

    scroll_height = function(self)
        return self.y2 - self.y1 - 4
    end,

    on_mouse_button_down = function(self, mx, my)
        if self:is_disabled() then
            return
        end

        self:on_mouse_button_hold(mx, my)
    end,

    on_mouse_button_hold = function(self, mx, my)
        if self:is_disabled() then
            return
        end

        local r = (self.y2 - 1 - my) / (self:height() - 2)
        r = CLAMP(0.0, r, 1.0)
        self.cur_value = math.floor(r * self.max_value)
        self.dialog:request_draw()
    end,

    draw = function(self)
        local theme = self.dialog:get_theme()
        local bg = theme.fg
        local left, top = self.x1 + 0.5, self.y1 + 0.5
        local right, bottom = self.x2 + 0.5, self.y2 + 0.5
        local state = SaveState()

        if self:is_disabled() then
            bg = allegro5.al_map_rgb(64, 64, 64)
        end

        allegro5.al_draw_rectangle(left, top, right, bottom, bg, 1)

        local ratio = self.cur_value / self.max_value
        local ypos = math.floor(bottom - 0.5 - math.floor(ratio * (self:height() - 7)))
        allegro5.al_draw_filled_rectangle(left + 0.5, ypos - 5, right - 0.5, ypos, theme.fg)

        state:__destroy()
    end,

    get_cur_value = function(self)
        return self.cur_value
    end,

    get_max_value = function(self)
        return self.max_value
    end,

    set_cur_value = function(self, v)
        self.cur_value = v
    end,
}, exports.Widget)

exports.HSlider = common.class({
    __name = "HSlider",

    __init__ = function(self, cur_value, max_value)
        if cur_value == nil then cur_value = 0 end
        if max_value == nil then max_value = 1 end

        exports.Widget.__init__(self)
        self.cur_value = cur_value
        self.max_value = max_value
    end,

    scroll_width = function(self)
        return self.x2 - self.x1 - 4
    end,

    on_mouse_button_down = function(self, mx, my)
        if self:is_disabled() then
            return
        end

        self:on_mouse_button_hold(mx, my)
    end,

    on_mouse_button_hold = function(self, mx, my)
        if self:is_disabled() then
            return
        end

        local r = (mx - self.x1) / self:scroll_width()
        r = CLAMP(0.0, r, 1.0)
        self.cur_value = math.floor(r * self.max_value)
        self.dialog:request_draw()
    end,

    draw = function(self)
        local theme = self.dialog:get_theme()
        local cy = math.floor((self.y1 + self.y2) / 2)
        local state = SaveState()
        local bg = theme.bg

        if self:is_disabled() then
            bg = allegro5.al_map_rgb(64, 64, 64)
        end

        allegro5.al_draw_filled_rectangle(self.x1, self.y1, self.x2, self.y2, bg)
        allegro5.al_draw_line(self.x1, cy, self.x2, cy, theme.fg, 0)

        local ratio = self.cur_value / self.max_value
        local xpos = self.x1 + math.floor(ratio * (self:scroll_width()))
        allegro5.al_draw_filled_rectangle(xpos, self.y1, xpos + 4, self.y2, theme.fg)

        state:__destroy()
    end,

    get_cur_value = function(self)
        return self.cur_value
    end,

    get_max_value = function(self)
        return self.max_value
    end,

    set_cur_value = function(self, v)
        self.cur_value = v
    end,
}, exports.Widget)

local CURSOR_WIDTH = 8

exports.TextEntry = common.class({
    __name = "TextEntry",

    __init__ = function(self, initial_text)
        if initial_text == nil then initial_text = "" end

        self.focused = false
        self.cursor_pos = 0
        self.left_pos = 0
        self.text = allegro5.al_ustr_new(initial_text)
    end,

    __destroy = function(self)
        allegro5.al_ustr_free(self.text)
    end,

    on_mouse_button_down = function(self, mx, my)
        if self:is_disabled() then
            return
        end
        self:set_cursor_pos(mx, my)
    end,

    set_cursor_pos = function(self, mx, my)
        local theme = self.dialog:get_theme()
        local r_pos = mx - self.x1

        local cursor_pos = 0
        local xpos = 0
        local success

        success = true
        while success and xpos < r_pos do
            success, cursor_pos = allegro5.al_ustr_next(self.text, cursor_pos)
            if success then
                xpos = allegro5.al_get_ustr_width(theme.font, UString(self.text, 0, cursor_pos):toustr())
            end
        end

        success = true
        while success and xpos > r_pos do
            success, cursor_pos = allegro5.al_ustr_prev(self.text, cursor_pos)
            if success then
                xpos = allegro5.al_get_ustr_width(theme.font, UString(self.text, 0, cursor_pos):toustr())
            end
        end

        if cursor_pos ~= self.cursor_pos then
            self.cursor_pos = cursor_pos
            self.dialog:request_draw()
        end
    end,

    want_key_focus = function(self)
        return not self:is_disabled()
    end,

    got_key_focus = function(self)
        self.focused = true
        self.dialog:request_draw()
    end,

    lost_key_focus = function(self)
        self.focused = false
        self.dialog:request_draw()
    end,

    on_key_down = function(self, event)
        if self:is_disabled() then
            return
        end


        if event.keycode == allegro5.ALLEGRO_KEY_LEFT then
            _, self.cursor_pos = allegro5.al_ustr_prev(self.text, self.cursor_pos)
        elseif event.keycode == allegro5.ALLEGRO_KEY_RIGHT then
            _, self.cursor_pos = allegro5.al_ustr_next(self.text, self.cursor_pos)
        elseif event.keycode == allegro5.ALLEGRO_KEY_HOME then
            self.cursor_pos = 0
        elseif event.keycode == allegro5.ALLEGRO_KEY_END then
            self.cursor_pos = tonumber(allegro5.al_ustr_size(self.text))
        elseif event.keycode == allegro5.ALLEGRO_KEY_DELETE then
            allegro5.al_ustr_remove_chr(self.text, self.cursor_pos)
        elseif event.keycode == allegro5.ALLEGRO_KEY_BACKSPACE then
            local success
            success, self.cursor_pos = allegro5.al_ustr_prev(self.text, self.cursor_pos)
            if success then
                allegro5.al_ustr_remove_chr(self.text, self.cursor_pos)
            end
        else
            if event.unichar >= string.byte(' ') then
                allegro5.al_ustr_insert_chr(self.text, self.cursor_pos, event.unichar)
                self.cursor_pos = self.cursor_pos + (allegro5.al_utf8_width(event.unichar))
            end
        end

        self:maybe_scroll()
        self.dialog:request_draw()
    end,

    maybe_scroll = function(self)
        local theme = self.dialog:get_theme()

        if self.cursor_pos < self.left_pos + 3 then
            if self.cursor_pos < 3 then
                self.left_pos = 0
            else
                self.left_pos = self.cursor_pos - 3
            end
        else
            while true do
                local tw = allegro5.al_get_ustr_width(theme.font,
                    UString(self.text, self.left_pos, self.cursor_pos):toustr())
                if self.x1 + tw + CURSOR_WIDTH < self.x2 then
                    break
                end
                local _
                _, self.left_pos = allegro5.al_ustr_next(self.text, self.left_pos)
            end
        end
    end,

    draw = function(self)
        local theme = self.dialog:get_theme()
        local state = SaveState()
        local bg = theme.bg

        if self:is_disabled() then
            bg = allegro5.al_map_rgb(64, 64, 64)
        end

        allegro5.al_draw_filled_rectangle(self.x1, self.y1, self.x2, self.y2, bg)

        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)

        if not self.focused then
            allegro5.al_draw_ustr(theme.font, theme.fg, self.x1, self.y1, 0, UString(self.text, self.left_pos):toustr())
        else
            local x = self.x1

            if self.cursor_pos > 0 then
                local sub = UString(self.text, self.left_pos, self.cursor_pos)
                allegro5.al_draw_ustr(theme.font, theme.fg, self.x1, self.y1, 0, sub:toustr())
                x = x + allegro5.al_get_ustr_width(theme.font, sub:toustr())
            end

            if self.cursor_pos == tonumber(allegro5.al_ustr_size(self.text)) then
                allegro5.al_draw_filled_rectangle(x, self.y1, x + CURSOR_WIDTH,
                    self.y1 + allegro5.al_get_font_line_height(theme.font), theme.fg)
            else
                local _, post_cursor = allegro5.al_ustr_next(self.text, self.cursor_pos)

                local sub = UString(self.text, self.cursor_pos, post_cursor)
                local subw = allegro5.al_get_ustr_width(theme.font, sub:toustr())
                allegro5.al_draw_filled_rectangle(x, self.y1, x + subw,
                    self.y1 + allegro5.al_get_font_line_height(theme.font), theme.fg)
                allegro5.al_draw_ustr(theme.font, theme.bg, x, self.y1, 0, sub:toustr())
                x = x + subw

                allegro5.al_draw_ustr(theme.font, theme.fg, x, self.y1, 0,
                    UString(self.text, post_cursor):toustr())
            end
        end

        state:__destroy()
    end,

    get_text = function(self)
        return c_string(allegro5.al_cstr(self.text))
    end,
}, exports.Widget)

return exports
