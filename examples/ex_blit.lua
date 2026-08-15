#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_blit.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

local INDEX_BASE = 1 -- lua is 1-based indexed
local atan2 = math.atan2 or math.atan ---@diagnostic disable-line: deprecated
local sqrt = math.sqrt
local pow = math.pow or function(x, y) return x ^ y end ---@diagnostic disable-line: deprecated
local floorf = math.floor

local malloc = allegro5_lua.C.malloc
local free = allegro5_lua.C.free
local memcpy = allegro5_lua.C.memcpy
local char_ptr = allegro5_lua.VectorOfChar.ptr

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    malloc = ffi.C.malloc
    free = ffi.C.free
    memcpy = ffi.C.memcpy

    char_ptr = function(ptr, i)
        return ffi.cast("char*", ptr) + i
    end
end

--[[ An example demonstrating different blending modes.
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
            local sat = pow(1.0 - 1 / (1 + d * 0.1), 5)
            local hue = 3 * a * 180 / allegro5.ALLEGRO_PI
            hue = (hue / 360 - floorf(hue / 360)) * 360
            allegro5.al_put_pixel(i, j, allegro5.al_color_hsv(hue, sat, 1))
        end
    end
    allegro5.al_put_pixel(0, 0, allegro5.al_map_rgb(0, 0, 0))
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

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)

    allegro5.al_clear_to_color(ex.background)

    local screen = allegro5.al_get_target_bitmap()

    set_xy(8, 8)

    --[[ Test 1. --]]
    --[[ Disabled: drawing to same bitmap is not supported. --]]
    --[[
   print("Screen -> Screen (%.1f fps)", get_fps(0))
   x, y = get_xy()
   allegro.al_draw_bitmap(ex.pattern, x, y, 0)

   start_timer(0)
   allegro.al_draw_bitmap_region(screen, x, y, iw, ih, x + 8 + iw, y, 0)
   stop_timer(0)
   set_xy(x, y + ih)
   --]]

    --[[ Test 2. --]]
    print("Screen -> Bitmap -> Screen (%.1f fps)", get_fps(1))
    x, y = get_xy()
    allegro5.al_draw_bitmap(ex.pattern, x, y, 0)

    local temp = allegro5.al_create_bitmap(iw, ih)
    allegro5.al_set_target_bitmap(temp)
    allegro5.al_clear_to_color(allegro5.al_map_rgba_f(1, 0, 0, 1))
    start_timer(1)
    allegro5.al_draw_bitmap_region(screen, x, y, iw, ih, 0, 0, 0)

    allegro5.al_set_target_bitmap(screen)
    allegro5.al_draw_bitmap(temp, x + 8 + iw, y, 0)
    stop_timer(1)
    set_xy(x, y + ih)

    allegro5.al_destroy_bitmap(temp)

    --[[ Test 3. --]]
    print("Screen -> Memory -> Screen (%.1f fps)", get_fps(2))
    x, y = get_xy()
    allegro5.al_draw_bitmap(ex.pattern, x, y, 0)

    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    local temp = allegro5.al_create_bitmap(iw, ih)
    allegro5.al_set_target_bitmap(temp)
    allegro5.al_clear_to_color(allegro5.al_map_rgba_f(1, 0, 0, 1))
    start_timer(2)
    allegro5.al_draw_bitmap_region(screen, x, y, iw, ih, 0, 0, 0)

    allegro5.al_set_target_bitmap(screen)
    allegro5.al_draw_bitmap(temp, x + 8 + iw, y, 0)
    stop_timer(2)
    set_xy(x, y + ih)

    allegro5.al_destroy_bitmap(temp)
    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_VIDEO_BITMAP)

    --[[ Test 4. --]]
    print("Screen -> Locked -> Screen (%.1f fps)", get_fps(3))
    x, y = get_xy()
    allegro5.al_draw_bitmap(ex.pattern, x, y, 0)

    start_timer(3)
    local lock = allegro5.al_lock_bitmap_region(screen, x, y, iw, ih,
        allegro5.ALLEGRO_PIXEL_FORMAT_ANY, allegro5.ALLEGRO_LOCK_READONLY)
    local format = lock.format
    local size = lock.pixel_size
    local data = malloc(size * iw * ih)
    for i = 0, ih - INDEX_BASE do
        memcpy(char_ptr(data, i * size * iw),
            char_ptr(lock.data, i * lock.pitch), size * iw)
    end
    allegro5.al_unlock_bitmap(screen)

    lock = allegro5.al_lock_bitmap_region(screen, x + 8 + iw, y, iw, ih, format,
        allegro5.ALLEGRO_LOCK_WRITEONLY)
    for i = 0, ih - INDEX_BASE do
        memcpy(char_ptr(lock.data, i * lock.pitch),
            char_ptr(data, i * size * iw), size * iw)
    end
    allegro5.al_unlock_bitmap(screen)
    free(data)
    stop_timer(3)
    set_xy(x, y + ih)
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

    ex.font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga", 0, 0)
    if not ex.font then
        abort_example(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga not found\n")
    end
    ex.background = allegro5.al_color_name("beige")
    ex.text = allegro5.al_color_name("black")
    ex.white = allegro5.al_color_name("white")
    ex.pattern = example_bitmap(100, 100)
end

local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()
    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    init_platform_specific()

    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Error creating display\n")
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
