#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_display_options.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local abort_example = common.abort_example

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ Test retrieving and settings possible modes. --]]

local font
local font_h = 0
local modes_count = 0
local options_count = 0
local status = ""
local flags, old_flags = 0, 0

local visible_rows = 0
local first_visible_row = 0

local selected_column = 0
local selected_mode = 0
local selected_option = 0

-- #define X(x, m) {#x, ALLEGRO_##x, 0, m, 0}
local function Option(x, m)
    return {
        name = x,
        option = allegro5["ALLEGRO_" .. x],
        value = 0,
        max_value = m,
        required = 0
    }
end

local options = {
    Option("COLOR_SIZE", 32),
    Option("RED_SIZE", 8),
    Option("GREEN_SIZE", 8),
    Option("BLUE_SIZE", 8),
    Option("ALPHA_SIZE", 8),
    Option("RED_SHIFT", 32),
    Option("GREEN_SHIFT", 32),
    Option("BLUE_SHIFT", 32),
    Option("ALPHA_SHIFT", 32),
    Option("DEPTH_SIZE", 32),
    Option("FLOAT_COLOR", 1),
    Option("FLOAT_DEPTH", 1),
    Option("STENCIL_SIZE", 32),
    Option("SAMPLE_BUFFERS", 1),
    Option("SAMPLES", 8),
    Option("RENDER_METHOD", 2),
    Option("SINGLE_BUFFER", 1),
    Option("SWAP_METHOD", 1),
    Option("VSYNC", 2),
    Option("COMPATIBLE_DISPLAY", 1),
    Option("MAX_BITMAP_SIZE", 65536),
    Option("SUPPORT_NPOT_BITMAP", 1),
    Option("CAN_DRAW_INTO_BITMAP", 1),
    Option("SUPPORT_SEPARATE_ALPHA", 1),
}
-- #undef X

local flag_names = {}

local function init_flags()
    -- #define X(f) if (1 << i == ALLEGRO_##f) flag_names[i] = #f
    for i = 0, 32 - INDEX_BASE do
        if bit.lshift(1, i) == allegro5.ALLEGRO_WINDOWED then flag_names[i + INDEX_BASE] = "WINDOWED" end
        if bit.lshift(1, i) == allegro5.ALLEGRO_FULLSCREEN then flag_names[i + INDEX_BASE] = "FULLSCREEN" end
        if bit.lshift(1, i) == allegro5.ALLEGRO_OPENGL then flag_names[i + INDEX_BASE] = "OPENGL" end
        if bit.lshift(1, i) == allegro5.ALLEGRO_RESIZABLE then flag_names[i + INDEX_BASE] = "RESIZABLE" end
        if bit.lshift(1, i) == allegro5.ALLEGRO_FRAMELESS then flag_names[i + INDEX_BASE] = "FRAMELESS" end
        if bit.lshift(1, i) == allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS then flag_names[i + INDEX_BASE] = "GENERATE_EXPOSE_EVENTS" end
        if bit.lshift(1, i) == allegro5.ALLEGRO_FULLSCREEN_WINDOW then flag_names[i + INDEX_BASE] = "FULLSCREEN_WINDOW" end
        if bit.lshift(1, i) == allegro5.ALLEGRO_MINIMIZED then flag_names[i + INDEX_BASE] = "MINIMIZED" end
    end
    -- #undef X
end

local function load_font()
    font = allegro5.al_create_builtin_font()
    if not font then
        abort_example("Error creating builtin font\n")
    end
    font_h = allegro5.al_get_font_line_height(font)
end

local function display_options(display)
    local y = 10
    local x = 10
    local n = options_count
    local dw = allegro5.al_get_display_width(display)
    local dh = allegro5.al_get_display_height(display)

    modes_count = allegro5.al_get_num_display_modes()

    local c = allegro5.al_map_rgb_f(0.8, 0.8, 1)
    allegro5.al_draw_textf(font, c, x, y, 0, "Create new display")
    y = y + font_h
    for i = first_visible_row, modes_count + 2 - INDEX_BASE do
        if i >= first_visible_row + visible_rows then break end

        local mode = allegro5.ALLEGRO_DISPLAY_MODE()
        if i > 1 then
            allegro5.al_get_display_mode(i - 2, mode)
        elseif i == 1 then
            mode.width = 800
            mode.height = 600
            mode.format = 0
            mode.refresh_rate = 0
        else
            mode.width = 800
            mode.height = 600
            mode.format = 0
            mode.refresh_rate = 0
        end
        if selected_column == 0 and selected_mode == i then
            c = allegro5.al_map_rgb_f(1, 1, 0)
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
            allegro5.al_draw_filled_rectangle(x, y, x + 300, y + font_h, c)
        end
        c = allegro5.al_map_rgb_f(0, 0, 0)
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
        if (i == first_visible_row and i > 0) or
            (i == first_visible_row + visible_rows - 1 and
                i < modes_count + 1) then
            allegro5.al_draw_textf(font, c, x, y, 0, "...")
        else
            -- lua < 5.3 has no integer type
            -- therefore %d will not work
            -- use lua string.format function instead
            allegro5.al_draw_text(font, c, x, y, 0, string.format("%s %d x %d (fmt: %x, %d Hz)",
                (function()
                    if i > 1 then
                        return "Fullscreen"
                    elseif i == 0 then
                        return "Windowed"
                    else
                        return "FS Window"
                    end
                end)(),
                mode.width, mode.height, mode.format, mode.refresh_rate))
        end
        y = y + font_h
    end

    x = dw / 2 + 10
    y = 10
    c = allegro5.al_map_rgb_f(0.8, 0.8, 1)
    allegro5.al_draw_textf(font, c, x, y, 0, "Options for new display")
    allegro5.al_draw_textf(font, c, dw - 10, y, allegro5.ALLEGRO_ALIGN_RIGHT, "(current display)")
    y = y + font_h
    for i = 0, n - INDEX_BASE do
        if selected_column == 1 and selected_option == i then
            c = allegro5.al_map_rgb_f(1, 1, 0)
            allegro5.al_draw_filled_rectangle(x, y, x + 300, y + font_h, c)
        end

        if options[i + INDEX_BASE].required == allegro5.ALLEGRO_REQUIRE then
            c = allegro5.al_map_rgb_f(0.5, 0, 0)
        elseif options[i + INDEX_BASE].required == allegro5.ALLEGRO_SUGGEST then
            c = allegro5.al_map_rgb_f(0, 0, 0)
        elseif options[i + INDEX_BASE].required == allegro5.ALLEGRO_DONTCARE then
            c = allegro5.al_map_rgb_f(0.5, 0.5, 0.5)
        end

        -- lua < 5.3 has no integer type
        -- therefore %d will not work
        -- use lua string.format function instead
        allegro5.al_draw_text(font, c, x, y, 0, string.format("%s: %d (%s)", options[i + INDEX_BASE].name,
            options[i + INDEX_BASE].value,
            (function()
                if options[i + INDEX_BASE].required == allegro5.ALLEGRO_REQUIRE then
                    return "required"
                elseif options[i + INDEX_BASE].required == allegro5.ALLEGRO_SUGGEST then
                    return "suggested"
                else
                    return "ignored"
                end
            end)()))

        c = allegro5.al_map_rgb_f(0.9, 0.5, 0.3)
        -- lua < 5.3 has no integer type
        -- therefore %d will not work
        -- use lua string.format function instead
        allegro5.al_draw_text(font, c, dw - 10, y, allegro5.ALLEGRO_ALIGN_RIGHT, string.format("%d",
            allegro5.al_get_display_option(display, options[i + INDEX_BASE].option)))
        y = y + font_h
    end

    c = allegro5.al_map_rgb_f(0, 0, 0.8)
    x = 10
    y = dh - font_h - 10
    y = y - font_h
    allegro5.al_draw_textf(font, c, x, y, 0, "PageUp/Down: modify values")
    y = y - font_h
    allegro5.al_draw_textf(font, c, x, y, 0, "Return: set mode or require option")
    y = y - font_h
    allegro5.al_draw_textf(font, c, x, y, 0, "Cursor keys: change selection")

    y = y - font_h * 2
    for i = 0, 32 - INDEX_BASE do
        if flag_names[i + INDEX_BASE] then
            local continue = false

            if bit.band(flags, (bit.lshift(1, i))) ~= 0 then
                c = allegro5.al_map_rgb_f(0.5, 0, 0)
                -- continue = false
            elseif bit.band(old_flags, (bit.lshift(1, i))) ~= 0 then
                c = allegro5.al_map_rgb_f(0.5, 0.4, 0.4)
                -- continue = false
            else
                continue = true
            end

            if not continue then
                allegro5.al_draw_text(font, c, x, y, 0, flag_names[i + INDEX_BASE])
                x = x + allegro5.al_get_text_width(font, flag_names[i + INDEX_BASE]) + 10
            end
        end
    end

    c = allegro5.al_map_rgb_f(1, 0, 0)
    allegro5.al_draw_text(font, c, dw / 2, dh - font_h, allegro5.ALLEGRO_ALIGN_CENTRE, status)
end

local function update_ui()
    local h = allegro5.al_get_display_height(allegro5.al_get_current_display())
    visible_rows = h / font_h - 10
end

local function main()
    local display
    local queue
    local timer
    local redraw = false

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    init_flags()
    allegro5.al_init_primitives_addon()

    -- local white = allegro.al_map_rgba_f(1, 1, 1, 1)

    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()
    allegro5.al_init_font_addon()

    display = allegro5.al_create_display(800, 600)
    if not display then
        abort_example("Could not create display.\n")
    end

    load_font()

    timer = allegro5.al_create_timer(1.0 / 60)

    modes_count = allegro5.al_get_num_display_modes()
    options_count = #options

    update_ui()

    allegro5.al_clear_to_color(allegro5.al_map_rgb_f(1, 1, 1))
    display_options(display)
    allegro5.al_flip_display()

    queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_start_timer(timer)

    while 1 do
        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
            if event.mouse.button == 1 then
                local dw = allegro5.al_get_display_width(display)
                local y = 10
                local row = (event.mouse.y - y) / font_h - 1
                local column = event.mouse.x / (dw / 2)
                if column == 0 then
                    if row >= 0 and row <= modes_count then
                        selected_column = column
                        selected_mode = row
                        redraw = true
                    end
                end
                if column == 1 then
                    if row >= 0 and row < options_count then
                        selected_column = column
                        selected_option = row
                        redraw = true
                    end
                end
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            local f = allegro5.al_get_display_flags(display)
            if f ~= flags then
                redraw = true
                flags = f
                old_flags = bit.bor(old_flags, f)
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_LEFT then
                selected_column = 0
                redraw = true
            end
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_RIGHT then
                selected_column = 1
                redraw = true
            end
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_UP then
                if selected_column == 0 then
                    selected_mode = selected_mode - 1
                end
                if selected_column == 1 then
                    selected_option = selected_option - 1
                end
                redraw = true
            end
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_DOWN then
                if selected_column == 0 then
                    selected_mode = selected_mode + 1
                end
                if selected_column == 1 then
                    selected_option = selected_option + 1
                end
                redraw = true
            end
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ENTER then
                if selected_column == 0 then
                    local mode = allegro5.ALLEGRO_DISPLAY_MODE()
                    local new_display
                    if selected_mode > 1 then
                        allegro5.al_get_display_mode(selected_mode - 2, mode)
                        allegro5.al_set_new_display_flags(allegro5.ALLEGRO_FULLSCREEN)
                    elseif selected_mode == 1 then
                        mode.width = 800
                        mode.height = 600
                        allegro5.al_set_new_display_flags(allegro5.ALLEGRO_FULLSCREEN_WINDOW)
                    else
                        mode.width = 800
                        mode.height = 600
                        allegro5.al_set_new_display_flags(allegro5.ALLEGRO_WINDOWED)
                    end

                    allegro5.al_destroy_font(font)
                    font = nil

                    new_display = allegro5.al_create_display(
                        mode.width, mode.height)
                    if new_display then
                        allegro5.al_destroy_display(display)
                        display = new_display
                        allegro5.al_set_target_backbuffer(display)
                        allegro5.al_register_event_source(queue,
                            allegro5.al_get_display_event_source(display))
                        update_ui()
                        status = "Display creation succeeded."
                    else
                        status = "Display creation failed."
                    end

                    load_font()
                end
                if selected_column == 1 then
                    options[selected_option + INDEX_BASE].required = options[selected_option + INDEX_BASE].required + 1
                    options[selected_option + INDEX_BASE].required = options[selected_option + INDEX_BASE].required % 3
                    allegro5.al_set_new_display_option(
                        options[selected_option + INDEX_BASE].option,
                        options[selected_option + INDEX_BASE].value,
                        options[selected_option + INDEX_BASE].required)
                end
                redraw = true
            end

            local change = 0
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_PGUP then
                change = 1
            end
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_PGDN then
                change = -1
            end

            if change ~= 0 and selected_column == 1 then
                options[selected_option + INDEX_BASE].value = options[selected_option + INDEX_BASE].value + change
                if options[selected_option + INDEX_BASE].value < 0 then
                    options[selected_option + INDEX_BASE].value = 0
                end
                if options[selected_option + INDEX_BASE].value >
                    options[selected_option + INDEX_BASE].max_value then
                    options[selected_option + INDEX_BASE].value =
                        options[selected_option + INDEX_BASE].max_value
                end
                allegro5.al_set_new_display_option(options[selected_option + INDEX_BASE].option,
                    options[selected_option + INDEX_BASE].value,
                    options[selected_option + INDEX_BASE].required)
                redraw = true
            end
        end

        if selected_mode < 0 then
            selected_mode = 0
        end
        if selected_mode > modes_count + 1 then
            selected_mode = modes_count + 1
        end
        if selected_option < 0 then
            selected_option = 0
        end
        if selected_option >= options_count then
            selected_option = options_count - 1
        end
        if selected_mode < first_visible_row then
            first_visible_row = selected_mode
        end
        if selected_mode > first_visible_row + visible_rows - 1 then
            first_visible_row = selected_mode - visible_rows + 1
        end

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            redraw = false
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(1, 1, 1))
            display_options(display)
            allegro5.al_flip_display()
        end
    end

    allegro5.al_destroy_font(font)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
