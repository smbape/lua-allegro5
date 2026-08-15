#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_color2.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local pointer_cast = common.pointer_cast

local INDEX_BASE = 1 -- lua is 1-based indexed

local cos = math.cos
local sin = math.sin
local sqrt = math.sqrt

local clock = allegro5_lua.C.clock
local CLOCKS_PER_SEC = allegro5_lua.C.CLOCKS_PER_SEC

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    clock = ffi.C.clock
end

--[[ al_get_current_time() measures wallclock time - but for the benchmark
 - result we prefer CPU time so clock() is better.
 --]]
local function current_clock()
   local c = clock()
   return tonumber(c) / CLOCKS_PER_SEC
end

local FPS = 60

local function Color()
    return {
        rgb = allegro5.ALLEGRO_COLOR(),
        l = 0,
        a = 0,
        b = 0,
    }
end

local example = {
    font = nil,
    lab = {},
    black = allegro5.ALLEGRO_COLOR(),
    white = allegro5.ALLEGRO_COLOR(),
    color = { Color(), Color() },
    mx = 0,
    my = 0,
    mb = 0, -- 1 = clicked, 2 = released, 3 = pressed
    slider = 0,
    top_y = 0,
    left_x = 0,
    slider_x = 0,
    half_x = 0,
}

local function draw_lab(l)
    if example.lab[l + INDEX_BASE] then return end

    example.lab[l + INDEX_BASE] = allegro5.al_create_bitmap(512, 512)
    local rg = allegro5.al_lock_bitmap(example.lab[l + INDEX_BASE],
        allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_8888_LE, allegro5.ALLEGRO_LOCK_WRITEONLY)
    local rg_data = pointer_cast("uint8_t", rg.data)
    local rg_pitch = rg.pitch
    local t0 = current_clock()
    for y = 0, 512 - INDEX_BASE do
        for x = 0, 512 - INDEX_BASE do
            local a = (x - 511.0 / 2) / (511.0 / 2)
            local b = (y - 511.0 / 2) / (511.0 / 2)
            b = -b
            local rgb = allegro5.al_color_lab(l / 511.0, a, b)
            if not allegro5.al_is_color_valid(rgb) then
                rgb = allegro5.al_map_rgb_f(0, 0, 0)
            end
            local red = 255 * rgb.r
            local green = 255 * rgb.g
            local blue = 255 * rgb.b

            local p = rg_data
            p = p + rg_pitch * y
            p = p + x * 4
            p[0] = red
            p[1] = green
            p[2] = blue
            p[3] = 255
        end
    end
    local t1 = current_clock()
    print(string.format("Initialization time = %g s", t1 - t0))
    allegro5.al_unlock_bitmap(example.lab[l + INDEX_BASE])

end

local function draw_range(ci)
    local l = example.color[ci + INDEX_BASE].l
    local cx = (example.color[ci + INDEX_BASE].a * 511.0 / 2) + 511.0 / 2
    local cy = (-example.color[ci + INDEX_BASE].b * 511.0 / 2) + 511.0 / 2
    local r = 2
    --[[ Loop around the center in outward circles, starting with a 3 x 3
    - rectangle, then 5 x 5, then 7 x 7, and so on.
    - Each loop has four sides, top, right, bottom, left. For example
    - these are the four loops for the 5 x 5 case:
    - 1 2 3 4 .
    - .       .
    - .       .
    - .       .
    - . . . . .
    -
    - o o o o 1
    - .       2
    - .       3
    - .       4
    - . . . . .
    -
    - o o o o o
    - .       o
    - .       o
    - . 3 2 1 1
    -
    - o o o o o
    - 4       o
    - 3       o
    - 2       o
    - 1 o o o o
    -
    - 1654321
    --]]
    while true do
        local found = false
        local x = cx - r / 2
        local y = cy - r / 2
        for i = 0, r * 4 - INDEX_BASE do
            if i < r then
                x = x + 1
            elseif i < r * 2 then
                y = y + 1
            elseif i < r * 3 then
                x = x - 1
            else
                y = y - 1
            end

            local a = (x - 511.0 / 2) / (511.0 / 2)
            local b = (y - 511.0 / 2) / (511.0 / 2)
            b = -b
            local rf, gf, bf = allegro5.al_color_lab_to_rgb(l, a, b)
            if rf < 0 or rf > 1 or gf < 0 or gf > 1 or bf < 0 or bf > 1 then
                -- continue
            else
                local rgb = { rf, gf, bf, 1 }
                local d = allegro5.al_color_distance_ciede2000(rgb, example.color[ci + INDEX_BASE].rgb)
                if d <= 0.05 then
                    if d > 0.04 then
                        allegro5.al_draw_pixel(example.half_x * ci + example.left_x + x,
                            example.top_y + y, example.white)
                    end
                    found = true
                end
            end
        end
        if not found then break end
        r = r + 2
        if r > 128 then break end
    end
end

local function init()
    example.black = allegro5.al_map_rgb_f(0, 0, 0)
    example.white = allegro5.al_map_rgb_f(1, 1, 1)
    example.left_x = 120
    example.top_y = 48
    example.slider_x = 48
    example.color[0 + INDEX_BASE].l = 0.5
    example.color[1 + INDEX_BASE].l = 0.5
    example.color[0 + INDEX_BASE].a = 0.2
    example.half_x = math.floor(allegro5.al_get_display_width(allegro5.al_get_current_display()) / 2)
end

local function draw_axis(x, y, a, a2, l,
                         tl, label, ticks,
                         numformat, num1, num2, num)
    allegro5.al_draw_line(x, y, x + l * cos(a), y - l * sin(a), example.white, 1)
    for i = 0, ticks - INDEX_BASE do
        local x2 = x + l * cos(a) * i / (ticks - 1)
        local y2 = y - l * sin(a) * i / (ticks - 1)
        allegro5.al_draw_line(x2, y2, x2 + tl * cos(a2), y2 - tl * sin(a2), example.white, 1)
        allegro5.al_draw_text(example.font, example.white,
            math.floor(x2 + (tl + 2) * cos(a2)), math.floor(y2 - (tl + 2) * sin(a2)), allegro5.ALLEGRO_ALIGN_RIGHT,
            string.format(numformat,
                num1 + i * (num2 - num1) / (ticks - 1)))
    end
    local lv = (num - num1) * l / (num2 - num1)
    allegro5.al_draw_filled_circle(x + lv * cos(a), y - lv * sin(a), 8, example.white)
    allegro5.al_draw_text(example.font, example.white,
        math.floor(x + (l + 4) * cos(a)) - 24, math.floor(y - (l + 4) * sin(a)) - 12, 0, label)
end

local function redraw()
    allegro5.al_clear_to_color(example.black)
    local w = allegro5.al_get_display_width(allegro5.al_get_current_display())
    local h = allegro5.al_get_display_height(allegro5.al_get_current_display())

    for ci = 0, 2 - INDEX_BASE do
        local cx = w / 2 * ci

        local l = example.color[ci + INDEX_BASE].l
        local a = example.color[ci + INDEX_BASE].a
        local b = example.color[ci + INDEX_BASE].b

        local rgb = example.color[ci + INDEX_BASE].rgb

        draw_lab(math.floor(l * 511))

        allegro5.al_draw_bitmap(example.lab[math.floor(l * 511) + INDEX_BASE], cx + example.left_x, example.top_y, 0)

        draw_axis(cx + example.left_x, example.top_y + 512.5, 0, allegro5.ALLEGRO_PI / -2, 512, 16,
            "a*", 11, "%.2f", -1, 1, a)
        draw_axis(cx + example.left_x - 0.5, example.top_y + 512, allegro5.ALLEGRO_PI / 2, allegro5.ALLEGRO_PI,
            512, 16, "b*", 11, "%.2f", -1, 1, b)

        allegro5.al_draw_text(example.font, example.white, cx + example.left_x + 36, 8, 0,
            string.format("L*a*b* = %.2f/%.2f/%.2f sRGB = %.2f/%.2f/%.2f",
                l, a, b, rgb.r, rgb.g, rgb.b))
        draw_axis(cx + example.slider_x - 0.5, example.top_y + 512, allegro5.ALLEGRO_PI / 2, allegro5.ALLEGRO_PI,
            512, 4, "L*", 3, "%.1f", 0, 1, l)

        local c = allegro5.al_map_rgb_f(rgb.r, rgb.g, rgb.b)
        allegro5.al_draw_filled_rectangle(cx, h - 128, cx + w / 2, h, c)

        draw_range(ci)
    end

    allegro5.al_draw_text(example.font, example.white, example.left_x + 36, 28, 0,
        "Lab colors visible in sRGB")
    allegro5.al_draw_text(example.font, example.white, example.half_x + example.left_x + 36, 28, 0,
        "ellipse shows CIEDE2000 between 0.4 and 0.5")

    allegro5.al_draw_line(w / 2, 0, w / 2, h - 128, example.white, 4)

    local dr = example.color[0 + INDEX_BASE].rgb.r - example.color[1 + INDEX_BASE].rgb.r
    local dg = example.color[0 + INDEX_BASE].rgb.g - example.color[1 + INDEX_BASE].rgb.g
    local db = example.color[0 + INDEX_BASE].rgb.b - example.color[1 + INDEX_BASE].rgb.b
    local drgb = sqrt(dr * dr + dg * dg + db * db)
    local dl = example.color[0 + INDEX_BASE].l - example.color[1 + INDEX_BASE].l
    local da = example.color[0 + INDEX_BASE].a - example.color[1 + INDEX_BASE].a
    db = example.color[0 + INDEX_BASE].b - example.color[1 + INDEX_BASE].b
    local dlab = sqrt(da * da + db * db + dl * dl)
    local d2000 = allegro5.al_color_distance_ciede2000(example.color[0 + INDEX_BASE].rgb,
        example.color[1 + INDEX_BASE].rgb)
    allegro5.al_draw_text(example.font, example.white, w / 2, h - 64,
        allegro5.ALLEGRO_ALIGN_CENTER, string.format("dRGB = %.2f", drgb))
    allegro5.al_draw_text(example.font, example.white, w / 2, h - 64 + 12,
        allegro5.ALLEGRO_ALIGN_CENTER, string.format("dLab = %.2f", dlab))
    allegro5.al_draw_text(example.font, example.white, w / 2, h - 64 + 24,
        allegro5.ALLEGRO_ALIGN_CENTER, string.format("CIEDE2000 = %.2f", d2000))

    allegro5.al_draw_rectangle(w / 2 - 80, h - 70, w / 2 + 80, h - 24,
        example.white, 4)
end

local function update()
    if example.mb == 1 or example.mb == 3 then
        if example.mb == 1 then
            local s = 0
            local mx = example.mx
            if example.mx >= example.half_x then
                mx = mx - example.half_x
                s = s + 2
            end
            if mx > example.left_x then
                s = s + 1
            end
            example.slider = s
        end

        if example.slider == 0 or example.slider == 2 then
            local l = example.my - example.top_y
            if l < 0 then l = 0 end
            if l > 511 then l = 511 end
            example.color[math.floor(example.slider / 2) + INDEX_BASE].l = 1 - l / 511.0
        else
            local ci = math.floor(example.slider / 2)
            local a = example.mx - example.left_x - ci * example.half_x
            local b = example.my - example.top_y
            b = 511 - b
            if a < 0 then a = 0 end
            if b < 0 then b = 0 end
            if a > 511 then a = 511 end
            if b > 511 then b = 511 end
            example.color[ci + INDEX_BASE].a = 2 * a / 511.0 - 1
            example.color[ci + INDEX_BASE].b = 2 * b / 511.0 - 1
        end
    end

    if example.mb == 1 then example.mb = 3 end
    if example.mb == 2 then example.mb = 0 end

    for ci = 0, 2 - INDEX_BASE do
        example.color[ci + INDEX_BASE].rgb = allegro5.al_color_lab(example.color[ci + INDEX_BASE].l,
            example.color[ci + INDEX_BASE].a, example.color[ci + INDEX_BASE].b)
    end
end

local function main()
    local w, h = 1280, 720
    local done = false
    local need_redraw = true

    if not allegro5.al_init() then
        abort_example("Failed to init Allegro.\n")
    end

    allegro5.al_init_font_addon()
    example.font = allegro5.al_create_builtin_font()

    init_platform_specific()

    local display = allegro5.al_create_display(w, h)
    if not display then
        abort_example("Error creating display.\n")
    end

    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()
    allegro5.al_init_primitives_addon()

    init()

    local timer = allegro5.al_create_timer(1.0 / FPS)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    allegro5.al_start_timer(timer)

    while not done do
        local event = allegro5.ALLEGRO_EVENT()

        if need_redraw then
            redraw()
            allegro5.al_flip_display()
            need_redraw = false
        end

        while true do
            allegro5.al_wait_for_event(queue, event)
            if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
                if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                    done = true
                end
            elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_AXES then
                example.mx = event.mouse.x
                example.my = event.mouse.y
            elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
                example.mb = 1
            elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_UP then
                example.mb = 2
            elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
                done = true
            elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
                update()
                need_redraw = true
            end

            if allegro5.al_is_event_queue_empty(queue) then
                break
            end
        end
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
