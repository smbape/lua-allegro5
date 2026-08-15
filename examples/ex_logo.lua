#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_logo.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local open_log = common.open_log
local init_platform_specific = common.init_platform_specific
local close_log = common.close_log
local log_printf = common.log_printf
local startswith = common.startswith
local rand = common.rand
local RAND_MAX = common.RAND_MAX

local INDEX_BASE = 1 -- lua is 1-based indexed

local sin = math.sin

local c_string = allegro5_lua.std.string
local clock = allegro5_lua.C.clock
local CLOCKS_PER_SEC = allegro5_lua.C.CLOCKS_PER_SEC

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    c_string = ffi.string
    clock = ffi.C.clock
end

--[[ al_get_current_time() measures wallclock time - but for the benchmark
 - result we prefer CPU time so clock() is better.
 --]]
local function current_clock()
   local c = clock()
   return tonumber(c) / CLOCKS_PER_SEC
end

--[[ Demo program which creates a logo by direct pixel manipulation of
 - bitmaps. Also uses alpha blending to create a real-time flash
 - effect (likely not visible with displays using memory bitmaps as it
 - is too slow).
 --]]

local logo, logo_flash = nil, nil
local logo_x, logo_y = 0, 0
local font
local cursor = 0
local selection = 0
local regenerate, editing = false, false
local config
local white = allegro5.ALLEGRO_COLOR()
local anim = 0

local function clamp(x)
    if x < 0 then
        return 0
    end
    if x > 1 then
        return 1
    end
    return x
end

local param_names = {
    "text", "font", "size", "shadow", "blur", "factor", "red", "green",
    "blue", nil
}

--[[ Note: To regenerate something close to the official Allegro logo,
 - you need to obtain the non-free "Utopia Regular Italic" font. Then
 - replace "DejaVuSans.ttf" with "putri.pfa" below.
 --]]
local param_values = {
    "Allegro", "data/DejaVuSans.ttf", "140", "10", "2", "0.5", "1.1",
    "1.5", "5"
}

--[[ Generates a bitmap with transparent background and the logo text.
 - The bitmap will have screen size. If 'bumpmap' is not NULL, it will
 - contain another bitmap which is a white, blurred mask of the logo
 - which we use for the flash effect.
 --]]
local function generate_logo(
    text,
    fontname,
    font_size,
    shadow_offset,
    blur_radius,
    blur_factor,
    light_red,
    light_green,
    light_blue,
    bumpmap
)
    local transparent = allegro5.al_map_rgba_f(0, 0, 0, 0)
    local state = allegro5.ALLEGRO_STATE()

    local dw = allegro5.al_get_bitmap_width(allegro5.al_get_target_bitmap())
    local dh = allegro5.al_get_bitmap_height(allegro5.al_get_target_bitmap())

    local cx = dw * 0.5
    local cy = dh * 0.5

    if startswith(fontname, "data/") then
        fontname = env.ALLEGRO_EXAMPLES_DATA_PATH .. fontname:sub(string.len("data") + 1)
    end

    local logofont = allegro5.al_load_font(fontname, -font_size, 0)
    if not font then
        log_printf("Could not load font " .. fontname .. "\n")
        return false, false
    end
    local xp, yp, w, h = allegro5.al_get_text_dimensions(logofont, text)

    allegro5.al_store_state(state, bit.bor(allegro5.ALLEGRO_STATE_TARGET_BITMAP, allegro5.ALLEGRO_STATE_BLENDER))

    --[[ Cheap blur effect to create a bump map. --]]
    local blur = allegro5.al_create_bitmap(dw, dh)
    allegro5.al_set_target_bitmap(blur)
    allegro5.al_clear_to_color(transparent)
    local br = blur_radius
    local bw = br * 2 + 1
    local c = allegro5.al_map_rgba_f(1, 1, 1, 1.0 / (bw * bw * blur_factor))
    allegro5.al_set_separate_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_INVERSE_ALPHA,
        allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
    for i = -br, br do
        for j = -br, br do
            allegro5.al_draw_text(logofont, c,
                cx - xp * 0.5 - w * 0.5 + i,
                cy - yp * 0.5 - h * 0.5 + j, 0, text)
        end
    end

    local left = cx - xp * 0.5 - w * 0.5 - br + xp
    local top = cy - yp * 0.5 - h * 0.5 - br + yp
    local right = left + w + br * 2
    local bottom = top + h + br * 2

    if left < 0 then
        left = 0
    end
    if top < 0 then
        top = 0
    end
    if right > dw - 1 then
        right = dw - 1
    end
    if bottom > dh - 1 then
        bottom = dh - 1
    end

    --[[ Cheap light effect. --]]
    local light = allegro5.al_create_bitmap(dw, dh)
    allegro5.al_set_target_bitmap(light)
    allegro5.al_clear_to_color(transparent)
    allegro5.al_lock_bitmap(blur, allegro5.ALLEGRO_PIXEL_FORMAT_ANY, allegro5.ALLEGRO_LOCK_READONLY)
    allegro5.al_lock_bitmap_region(light, left, top,
        1 + right - left, 1 + bottom - top,
        allegro5.ALLEGRO_PIXEL_FORMAT_ANY, allegro5.ALLEGRO_LOCK_WRITEONLY)
    for y = top, bottom do
        for x = left, right do
            local c = allegro5.al_get_pixel(blur, x, y)
            local c1 = allegro5.al_get_pixel(blur, x - 1, y - 1)
            local c2 = allegro5.al_get_pixel(blur, x + 1, y + 1)
            local r, g, b, a = allegro5.al_unmap_rgba_f(c)
            local r1, g1, b1, a1 = allegro5.al_unmap_rgba_f(c1)
            local r2, g2, b2, a2 = allegro5.al_unmap_rgba_f(c2)

            local d = r2 - r1 + 0.5
            r = clamp(d * light_red)
            g = clamp(d * light_green)
            b = clamp(d * light_blue)

            c = allegro5.al_map_rgba_f(r, g, b, a)
            allegro5.al_put_pixel(x, y, c)
        end
    end
    allegro5.al_unlock_bitmap(light)
    allegro5.al_unlock_bitmap(blur)

    if bumpmap then
        bumpmap = blur
    else
        allegro5.al_destroy_bitmap(blur)
    end

    --[[ Create final logo --]]
    logo = allegro5.al_create_bitmap(dw, dh)
    allegro5.al_set_target_bitmap(logo)
    allegro5.al_clear_to_color(transparent)

    --[[ Draw a shadow. --]]
    c = allegro5.al_map_rgba_f(0, 0, 0, 0.5 / 9)
    allegro5.al_set_separate_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_INVERSE_ALPHA,
        allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
    for i = -1, 1 do
        for j = -1, 1 do
            allegro5.al_draw_text(logofont, c,
                cx - xp * 0.5 - w * 0.5 + shadow_offset + i,
                cy - yp * 0.5 - h * 0.5 + shadow_offset + j,
                0, text)
        end
    end

    --[[ Then draw the lit text we made before on top. --]]
    allegro5.al_set_separate_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_INVERSE_ALPHA,
        allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
    allegro5.al_draw_bitmap(light, 0, 0, 0)
    allegro5.al_destroy_bitmap(light)

    allegro5.al_restore_state(state)
    allegro5.al_destroy_font(logofont)

    return logo, bumpmap
end

--[[ Draw the checkerboard background. --]]
local function draw_background()
    local c = {}
    c[0 + INDEX_BASE] = allegro5.al_map_rgba(0xaa, 0xaa, 0xaa, 0xff)
    c[1 + INDEX_BASE] = allegro5.al_map_rgba(0x99, 0x99, 0x99, 0xff)

    for i = 0, math.floor(640 / 16) - INDEX_BASE do
        for j = 0, math.floor(480 / 16) - INDEX_BASE do
            allegro5.al_draw_filled_rectangle(i * 16, j * 16,
                i * 16 + 16, j * 16 + 16,
                c[bit.band((i + j), 1) + INDEX_BASE])
        end
    end
end

--[[ Print out the current logo parameters. --]]
local function print_parameters()
    local state = allegro5.ALLEGRO_STATE()
    local normal = allegro5.al_map_rgba_f(0, 0, 0, 1)
    local light = allegro5.al_map_rgba_f(0, 0, 1, 1)
    local label = allegro5.al_map_rgba_f(0.2, 0.2, 0.2, 1)

    allegro5.al_store_state(state, allegro5.ALLEGRO_STATE_BLENDER)

    local th = allegro5.al_get_font_line_height(font) + 3
    for i = 0, #param_names - INDEX_BASE do
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
        allegro5.al_draw_textf(font, label, 2, 2 + i * th, 0, "%s", param_names[i + INDEX_BASE])
    end
    for i = 0, #param_names - INDEX_BASE do
        local y = 2 + i * th
        allegro5.al_draw_filled_rectangle(75, y, 375, y + th - 2,
            allegro5.al_map_rgba_f(0.5, 0.5, 0.5, 0.5))
        allegro5.al_draw_textf(font, (function() if i == selection then return light else return normal end end)(), 75, y,
            0, "%s", param_values[i + INDEX_BASE])
        if i == selection and editing and
            bit.band(math.floor(allegro5.al_get_time() * 2), 1) ~= 0 then
            local x = 75 + allegro5.al_get_text_width(font, param_values[i + INDEX_BASE])
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
            allegro5.al_draw_line(x, y, x, y + th, white, 0)
        end
    end

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
    allegro5.al_draw_textf(font, normal, 400, 2, 0, "%s", "R - Randomize")
    allegro5.al_draw_textf(font, normal, 400, 2 + th, 0, "%s", "S - Save as logo.png")

    allegro5.al_draw_textf(font, normal, 2, 480 - th * 2 - 2, 0, "%s",
        "To modify, press Return, then enter value, "
        .. "then Return again.")
    allegro5.al_draw_textf(font, normal, 2, 480 - th - 2, 0, "%s",
        "Use cursor up/down to "
        .. "select the value to modify.")
    allegro5.al_restore_state(state)
end

local function rnum(min, max)
    local x = rand() / RAND_MAX
    x = min + x * (max - min)
    local s = string.format("%.1f", x)
    return s
end

local function randomize()
    param_values[3 + INDEX_BASE] = rnum(2, 12)
    param_values[4 + INDEX_BASE] = rnum(1, 8)
    param_values[5 + INDEX_BASE] = rnum(0.1, 1)
    param_values[6 + INDEX_BASE] = rnum(0, 5)
    param_values[7 + INDEX_BASE] = rnum(0, 5)
    param_values[8 + INDEX_BASE] = rnum(0, 5)
    regenerate = true
end

local function save()
    allegro5.al_save_bitmap("logo.png", logo)
end

local function mouse_click(x, y)
    local th = allegro5.al_get_font_line_height(font) + 3
    local sel = math.floor((y - 2) / th)
    if x < 400 then
        for i = 0, #param_names - INDEX_BASE do
            if sel == i then
                selection = i
                cursor = #param_values[selection + INDEX_BASE]
                editing = true
            end
        end
    elseif x < 500 then
        if sel == 0 then
            randomize()
        end
        if sel == 1 then
            save()
        end
    end
end

local function render()
    local t = allegro5.al_get_time()
    if regenerate then
        allegro5.al_destroy_bitmap(logo)
        allegro5.al_destroy_bitmap(logo_flash)
        logo = nil
        regenerate = false
    end
    if not logo then
        local t0, t1
        --[[ Generate a new logo. --]]
        log_printf("Generate a new logo time = ")
        t0 = current_clock()
        local fulllogo, fullflash = generate_logo(param_values[0 + INDEX_BASE],
            param_values[1 + INDEX_BASE],
            math.floor(tonumber(param_values[2 + INDEX_BASE])),
            tonumber(param_values[3 + INDEX_BASE]),
            tonumber(param_values[4 + INDEX_BASE]),
            tonumber(param_values[5 + INDEX_BASE]),
            tonumber(param_values[6 + INDEX_BASE]),
            tonumber(param_values[7 + INDEX_BASE]),
            tonumber(param_values[8 + INDEX_BASE]),
            true)
        t1 = current_clock()
        log_printf("%g s\n", t1 - t0)
        if not fulllogo then
            return
        end
        local left, top, right, bottom = 640, 480, -1, -1
        --[[ Crop out the non-transparent part. --]]
        log_printf("Crop out the non-transparent part time = ")
        t0 = current_clock()
        allegro5.al_lock_bitmap(fulllogo, allegro5.ALLEGRO_PIXEL_FORMAT_ANY, allegro5.ALLEGRO_LOCK_READONLY)
        for y = 0, 480 - INDEX_BASE do
            for x = 0, 640 - INDEX_BASE do
                local c = allegro5.al_get_pixel(fulllogo, x, y)
                local r, g, b, a = allegro5.al_unmap_rgba_f(c)
                if a > 0 then
                    if x < left then
                        left = x
                    end
                    if y < top then
                        top = y
                    end
                    if x > right then
                        right = x
                    end
                    if y > bottom then
                        bottom = y
                    end
                end
            end
        end
        allegro5.al_unlock_bitmap(fulllogo)
        t1 = current_clock()
        log_printf("%g s\n", t1 - t0)

        if left == 640 then
            left = 0
        end
        if top == 480 then
            top = 0
        end
        if right < left then
            right = left
        end
        if bottom < top then
            bottom = top
        end

        local crop = allegro5.al_create_sub_bitmap(fulllogo, left, top,
            1 + right - left, 1 + bottom - top)
        logo = allegro5.al_clone_bitmap(crop)
        allegro5.al_destroy_bitmap(crop)
        allegro5.al_destroy_bitmap(fulllogo)

        crop = allegro5.al_create_sub_bitmap(fullflash, left, top,
            1 + right - left, 1 + bottom - top)
        logo_flash = allegro5.al_clone_bitmap(crop)
        allegro5.al_destroy_bitmap(crop)
        allegro5.al_destroy_bitmap(fullflash)

        logo_x = left
        logo_y = top

        t = allegro5.al_get_time()
        anim = t
    end
    draw_background()

    --[[ For half a second, display our flash animation. --]]
    if t - anim < 0.5 then
        local state = allegro5.ALLEGRO_STATE()
        local f = sin(allegro5.ALLEGRO_PI * ((t - anim) / 0.5))
        local c = allegro5.al_map_rgb_f(f * 0.3, f * 0.3, f * 0.3)
        allegro5.al_store_state(state, allegro5.ALLEGRO_STATE_BLENDER)
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
        allegro5.al_draw_tinted_bitmap(logo, allegro5.al_map_rgba_f(1, 1, 1, 1 - f), logo_x, logo_y, 0)
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
        for j = -2, 2, 2 do
            for i = -2, 2, 2 do
                allegro5.al_draw_tinted_bitmap(logo_flash, c, logo_x + i, logo_y + j, 0)
            end
        end
        allegro5.al_restore_state(state)
    else
        allegro5.al_draw_bitmap(logo, logo_x, logo_y, 0)
    end


    print_parameters()
end

local function main()
    local redraw = false
    local quit = false

    if not allegro5.al_init() then
        abort_example("Could not initialise Allegro\n")
    end

    open_log()

    allegro5.al_init_primitives_addon()
    allegro5.al_install_mouse()
    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    allegro5.al_init_ttf_addon()
    init_platform_specific()

    white = allegro5.al_map_rgba_f(1, 1, 1, 1)

    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Could not create display\n")
    end
    allegro5.al_set_window_title(display, "Allegro Logo Generator")
    allegro5.al_install_keyboard()

    --[[ Read logo parameters from logo.ini (if it exists). --]]
    config = allegro5.al_load_config_file("logo.ini")
    if not config then
        config = allegro5.al_create_config()
    end
    for i = 1, #param_names do
        local value = allegro5.al_get_config_value(config, "logo", param_names[i])
        if value and value ~= "" then
            param_values[i] = value
        end
    end

    font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf", 12, 0)
    if not font then
        abort_example("Could not load font " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf\n")
    end

    local timer = allegro5.al_create_timer(1.0 / 60)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_start_timer(timer)
    while not quit do
        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                quit = true
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_ENTER then
                if editing then
                    regenerate = true
                    editing = false
                else
                    cursor = #param_values[selection + INDEX_BASE]
                    editing = true
                end
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_UP then
                if selection > 0 then
                    selection = selection - 1
                    cursor = #param_values[selection + INDEX_BASE]
                    editing = false
                end
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_DOWN then
                if param_names[selection + 1 + INDEX_BASE] then
                    selection = selection + 1
                    cursor = #param_values[selection + INDEX_BASE]
                    editing = false
                end
            else
                local c = event.keyboard.unichar
                if editing then
                    if event.keyboard.keycode == allegro5.ALLEGRO_KEY_BACKSPACE then
                        if cursor > 0 then
                            local u = allegro5.al_ustr_new(param_values[selection + INDEX_BASE])
                            local success
                            success, cursor = allegro5.al_ustr_prev(u, cursor)
                            if success then
                                allegro5.al_ustr_remove_chr(u, cursor)
                                param_values[selection + INDEX_BASE] = c_string(allegro5.al_cstr(u))
                            end
                            allegro5.al_ustr_free(u)
                        end
                    elseif c >= 32 then
                        local u = allegro5.al_ustr_new(param_values[selection + INDEX_BASE])
                        cursor = cursor + allegro5.al_ustr_set_chr(u, cursor, c)
                        allegro5.al_ustr_set_chr(u, cursor, 0)
                        param_values[selection + INDEX_BASE] = c_string(allegro5.al_cstr(u))
                        allegro5.al_ustr_free(u)
                    end
                else
                    if c == string.byte('r') then
                        randomize()
                    end
                    if c == string.byte('s') then
                        save()
                    end
                end
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
            if event.mouse.button == 1 then
                mouse_click(event.mouse.x, event.mouse.y)
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        end

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            redraw = false

            render()

            allegro5.al_flip_display()
        end
    end

    --[[ Write modified parameters back to logo.ini. --]]
    for i = 0, #param_names - INDEX_BASE do
        allegro5.al_set_config_value(config, "logo", param_names[i + INDEX_BASE],
            param_values[i + INDEX_BASE])
    end
    allegro5.al_save_config_file("logo.ini", config)
    allegro5.al_destroy_config(config)

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
