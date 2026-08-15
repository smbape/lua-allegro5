#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_clip.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

local INDEX_BASE = 1 -- lua is 1-based indexed
local atan2 = math.atan2 or math.atan ---@diagnostic disable-line: deprecated
local sqrt = math.sqrt
local pow = math.pow or function(x, y) return x ^ y end ---@diagnostic disable-line: deprecated

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ Test performance of allegro.al_draw_bitmap_region, allegro.al_create_sub_bitmap and
 - allegro.al_set_clipping_rectangle when clipping a bitmap.
 --]]

local ex = {
    pattern = nil,
    font = nil,
    queue = nil,
    background = allegro5.ALLEGRO_COLOR(),
    text = allegro5.ALLEGRO_COLOR(),
    white = allegro5.ALLEGRO_COLOR(),

    timer = { 0, 0, 0, 0 },
    counter = { 0, 0, 0, 0 },
    FPS = 0,
    text_x = 0,
    text_y = 0,
}

local function example_bitmap(w, h)
    local mx = w * 0.5
    local my = h * 0.5
    local state = allegro5.ALLEGRO_STATE()
    local pattern = allegro5.al_create_bitmap(w, h)
    allegro5.al_store_state(state, allegro5.ALLEGRO_STATE_TARGET_BITMAP)
    allegro5.al_set_target_bitmap(pattern)
    allegro5.al_lock_bitmap(pattern, allegro5.ALLEGRO_PIXEL_FORMAT_ANY, allegro5.ALLEGRO_LOCK_WRITEONLY)
    for i = 0, w - INDEX_BASE do
        for j = 0, h - INDEX_BASE do
            local a = atan2(i - mx, j - my)
            local d = sqrt(pow(i - mx, 2) + pow(j - my, 2))
            local l = 1 - pow(1.0 - 1 / (1 + d * 0.1), 5)
            local hue = a * 180 / allegro5.ALLEGRO_PI
            local sat = 1
            if i == 0 or j == 0 or i == w - 1 or j == h - 1 then
                hue = hue + 180
            elseif i == 1 or j == 1 or i == w - 2 or j == h - 2 then
                hue = hue + 180
                sat = 0.5
            end
            allegro5.al_put_pixel(i, j, allegro5.al_color_hsl(hue, sat, l))
        end
    end
    allegro5.al_unlock_bitmap(pattern)
    allegro5.al_restore_state(state)
    return pattern
end

local function set_xy(x, y)
    ex.text_x = x
    ex.text_y = y
end

local function get_xy()
    return ex.text_x, ex.text_y
end

local function print(format, ...)
    local th = allegro5.al_get_font_line_height(ex.font)
    local message = string.format(format, ...)
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
    allegro5.al_draw_textf(ex.font, ex.text, ex.text_x, ex.text_y, 0, "%s", message)
    ex.text_y = ex.text_y + th
end

local function start_timer(i)
    i = i + INDEX_BASE
    ex.timer[i] = ex.timer[i] - allegro5.al_get_time()
    ex.counter[i] = ex.counter[i] + 1
end

local function stop_timer(i)
    i = i + INDEX_BASE
    ex.timer[i] = ex.timer[i] + allegro5.al_get_time()
end

local function get_fps(i)
    i = i + INDEX_BASE
    if ex.timer[i] == 0 then
        return 0
    end
    return ex.counter[i] / ex.timer[i]
end

local function draw()
    local x, y
    local iw = allegro5.al_get_bitmap_width(ex.pattern)
    local ih = allegro5.al_get_bitmap_height(ex.pattern)
    local cx, cy, cw, ch = allegro5.al_get_clipping_rectangle()
    local gap = 8

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)

    allegro5.al_clear_to_color(ex.background)

    --[[ Test 1. --]]
    set_xy(8, 8)
    print("al_draw_bitmap_region (%.1f fps)", get_fps(0))
    x, y = get_xy()
    allegro5.al_draw_bitmap(ex.pattern, x, y, 0)

    start_timer(0)
    allegro5.al_draw_bitmap_region(ex.pattern, 1, 1, iw - 2, ih - 2,
        x + 8 + iw + 1, y + 1, 0)
    stop_timer(0)
    set_xy(x, y + ih + gap)

    --[[ Test 2. --]]
    print("al_create_sub_bitmap (%.1f fps)", get_fps(1))
    x, y = get_xy()
    allegro5.al_draw_bitmap(ex.pattern, x, y, 0)

    start_timer(1)
    local temp = allegro5.al_create_sub_bitmap(ex.pattern, 1, 1, iw - 2, ih - 2)
    allegro5.al_draw_bitmap(temp, x + 8 + iw + 1, y + 1, 0)
    allegro5.al_destroy_bitmap(temp)
    stop_timer(1)
    set_xy(x, y + ih + gap)

    --[[ Test 3. --]]
    print("al_set_clipping_rectangle (%.1f fps)", get_fps(2))
    x, y = get_xy()
    allegro5.al_draw_bitmap(ex.pattern, x, y, 0)

    start_timer(2)
    allegro5.al_set_clipping_rectangle(x + 8 + iw + 1, y + 1, iw - 2, ih - 2)
    allegro5.al_draw_bitmap(ex.pattern, x + 8 + iw, y, 0)
    allegro5.al_set_clipping_rectangle(cx, cy, cw, ch)
    stop_timer(2)
    set_xy(x, y + ih + gap)
end

local function tick()
    draw()
    allegro5.al_flip_display()
end

local function run()
    local event = allegro5.ALLEGRO_EVENT()
    local need_draw = true

    while true do
        if need_draw and allegro5.al_is_event_queue_empty(ex.queue) then
            tick()
            need_draw = false
        end

        allegro5.al_wait_for_event(ex.queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            return
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                return
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            need_draw = true
        end
    end
end

local function init()
    ex.FPS = 60

    ex.font = allegro5.al_create_builtin_font()
    if not ex.font then
        abort_example("Error creating builtin font.\n")
    end
    ex.background = allegro5.al_color_name("beige")
    ex.text = allegro5.al_color_name("blue")
    ex.white = allegro5.al_color_name("white")
    ex.pattern = example_bitmap(100, 100)
end

local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()
    allegro5.al_init_font_addon()
    init_platform_specific()

    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Error creating display.\n")
    end

    init()

    local timer = allegro5.al_create_timer(1.0 / ex.FPS)

    ex.queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(ex.queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(ex.queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(ex.queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(ex.queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_start_timer(timer)
    run()

    allegro5.al_destroy_event_queue(ex.queue)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
