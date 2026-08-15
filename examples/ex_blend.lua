#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_blend.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local pointer_cast = common.pointer_cast

local INDEX_BASE = 1 -- lua is 1-based indexed

local sqrt = math.sqrt

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ An example demonstrating different blending modes.
 --]]


--[[ A structure holding all variables of our example program. --]]
local ex = {
    example = nil, --[[ Our example bitmap. --]]
    offscreen = nil, --[[ An offscreen buffer, for testing. --]]
    memory = nil, --[[ A memory buffer, for testing. --]]
    myfont = nil, --[[ Our font. --]]
    queue = nil, --[[ Our events queue. --]]
    image = 0, --[[ Which test image to use. --]]
    mode = 0, --[[ How to draw it. --]]
    BUTTONS_X = 0, --[[ Where to draw buttons. --]]

    FPS = 0,
    last_second = 0,
    frames_accum = 0,
    fps = 0,
}

--[[ Print some text with a shadow. --]]
local function print(x, y, vertical, format, ...)
    local message = string.format(format, ...)
    local color = allegro5.ALLEGRO_COLOR()

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
    local h = allegro5.al_get_font_line_height(ex.myfont)

    for j = 0, 1 do
        if j == 0 then
            color = allegro5.al_map_rgb(0, 0, 0)
        else
            color = allegro5.al_map_rgb(255, 255, 255)
        end

        if vertical then
            local ui = allegro5.ALLEGRO_USTR_INFO()
            local us = allegro5.al_ref_cstr(ui, message)
            for i = 0, tonumber(allegro5.al_ustr_length(us)) - 1 do
                local letter = allegro5.ALLEGRO_USTR_INFO()
                allegro5.al_draw_ustr(ex.myfont, color, x + 1 - j, y + 1 - j + h * i, 0,
                    allegro5.al_ref_ustr(letter, us, allegro5.al_ustr_offset(us, i),
                        allegro5.al_ustr_offset(us, i + 1)))
            end
        else
            allegro5.al_draw_text(ex.myfont, color, x + 1 - j, y + 1 - j, 0, message)
        end
    end
end

--[[ Create an example bitmap. --]]
local function create_example_bitmap()
    local bitmap = allegro5.al_create_bitmap(100, 100)
    local locked = allegro5.al_lock_bitmap(bitmap, allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_8888, allegro5.ALLEGRO_LOCK_WRITEONLY)
    local data = pointer_cast("unsigned char", locked.data)

    for j = 0, 100 - INDEX_BASE do
        for i = 0, 100 - INDEX_BASE do
            local x, y = i - 50, j - 50
            local r = sqrt(x * x + y * y)
            local rc = 1 - r / 50.0
            if rc < 0 then
                rc = 0
            end
            data[i * 4 + 0] = i * 255 / 100
            data[i * 4 + 1] = j * 255 / 100
            data[i * 4 + 2] = rc * 255
            data[i * 4 + 3] = rc * 255
        end
        data = data + locked.pitch
    end
    allegro5.al_unlock_bitmap(bitmap)

    return bitmap
end

--[[ Draw our example scene. --]]
local function draw()
    local target = allegro5.al_get_target_bitmap()

    local blend_names = { "ZERO", "ONE", "allegro.ALPHA", "INVERSE" }
    local blend_vnames = { "ZERO", "ONE", "allegro.ALPHA", "INVER" }
    local blend_modes = { allegro5.ALLEGRO_ZERO, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ALPHA,
        allegro5.ALLEGRO_INVERSE_ALPHA }
    local x, y = 40, 40

    allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0.5, 0.5, 0.5))

    local test = {
        allegro5.al_map_rgba_f(1, 1, 1, 1),
        allegro5.al_map_rgba_f(1, 1, 1, 0.5),
        allegro5.al_map_rgba_f(1, 1, 1, 0.25),
        allegro5.al_map_rgba_f(1, 0, 0, 0.75),
        allegro5.al_map_rgba_f(0, 0, 0, 0),
    }

    print(x, 0, false, "D  E  S  T  I  N  A  T  I  O  N  (%0.2f fps)", ex.fps)
    print(0, y, true, "S O U R C E")
    for i = 0, 4 - INDEX_BASE do
        print(x + i * 110, 20, false, blend_names[i + INDEX_BASE])
        print(20, y + i * 110, true, blend_vnames[i + INDEX_BASE])
    end

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
    if ex.mode >= 1 and ex.mode <= 5 then
        allegro5.al_set_target_bitmap(ex.offscreen)
        allegro5.al_clear_to_color(test[ex.mode - 1 + INDEX_BASE])
    end
    if ex.mode >= 6 and ex.mode <= 10 then
        allegro5.al_set_target_bitmap(ex.memory)
        allegro5.al_clear_to_color(test[ex.mode - 6 + INDEX_BASE])
    end

    for j = 0, 4 - INDEX_BASE do
        for i = 0, 4 - INDEX_BASE do
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, blend_modes[j + INDEX_BASE], blend_modes[i + INDEX_BASE]);
            if ex.image == 0 then
                allegro5.al_draw_bitmap(ex.example, x + i * 110, y + j * 110, 0);
            elseif ex.image >= 1 and ex.image <= 6 then
                allegro5.al_draw_filled_rectangle(x + i * 110, y + j * 110,
                    x + i * 110 + 100, y + j * 110 + 100,
                    test[ex.image - 1 + INDEX_BASE]);
            end
        end
    end

    if ex.mode >= 1 and ex.mode <= 5 then
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA);
        allegro5.al_set_target_bitmap(target);
        allegro5.al_draw_bitmap_region(ex.offscreen, x, y, 430, 430, x, y, 0);
    end
    if ex.mode >= 6 and ex.mode <= 10 then
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA);
        allegro5.al_set_target_bitmap(target);
        allegro5.al_draw_bitmap_region(ex.memory, x, y, 430, 430, x, y, 0);
    end

    local IS = function(x) if ex.image == x then return "*" else return " " end end
    print(ex.BUTTONS_X, 20 * 1, false, "What to draw")
    print(ex.BUTTONS_X, 20 * 2, false, "%s Picture", IS(0))
    print(ex.BUTTONS_X, 20 * 3, false, "%s Rec1 (1/1/1/1)", IS(1))
    print(ex.BUTTONS_X, 20 * 4, false, "%s Rec2 (1/1/1/.5)", IS(2))
    print(ex.BUTTONS_X, 20 * 5, false, "%s Rec3 (1/1/1/.25)", IS(3))
    print(ex.BUTTONS_X, 20 * 6, false, "%s Rec4 (1/0/0/.75)", IS(4))
    print(ex.BUTTONS_X, 20 * 7, false, "%s Rec5 (0/0/0/0)", IS(5))

    local IS = function(x) if ex.mode == x then return "*" else return " " end end
    print(ex.BUTTONS_X, 20 * 9, false, "Where to draw")
    print(ex.BUTTONS_X, 20 * 10, false, "%s screen", IS(0))

    print(ex.BUTTONS_X, 20 * 11, false, "%s offscreen1", IS(1))
    print(ex.BUTTONS_X, 20 * 12, false, "%s offscreen2", IS(2))
    print(ex.BUTTONS_X, 20 * 13, false, "%s offscreen3", IS(3))
    print(ex.BUTTONS_X, 20 * 14, false, "%s offscreen4", IS(4))
    print(ex.BUTTONS_X, 20 * 15, false, "%s offscreen5", IS(5))

    print(ex.BUTTONS_X, 20 * 16, false, "%s memory1", IS(6))
    print(ex.BUTTONS_X, 20 * 17, false, "%s memory2", IS(7))
    print(ex.BUTTONS_X, 20 * 18, false, "%s memory3", IS(8))
    print(ex.BUTTONS_X, 20 * 19, false, "%s memory4", IS(9))
    print(ex.BUTTONS_X, 20 * 20, false, "%s memory5", IS(10))
end

--[[ Called a fixed amount of times per second. --]]
local function tick()
    --[[ Count frames during the last second or so. --]]
    local t = allegro5.al_get_time()
    if t >= ex.last_second + 1 then
        ex.fps = ex.frames_accum / (t - ex.last_second)
        ex.frames_accum = 0
        ex.last_second = t
    end

    draw()
    allegro5.al_flip_display()
    ex.frames_accum = ex.frames_accum + 1
end

--[[ Run our test. --]]
local function run()
    local event = allegro5.ALLEGRO_EVENT()
    local need_draw = true

    while true do
        --[[ Perform frame skipping so we don't fall behind the timer events. --]]
        if need_draw and allegro5.al_is_event_queue_empty(ex.queue) then
            tick()
            need_draw = false
        end

        allegro5.al_wait_for_event(ex.queue, event)

        --[[ Was the X button on the window pressed? --]]
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            return

            --[[ Was a key pressed? --]]
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                return
            end

            --[[ Is it time for the next timer tick? --]]
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            need_draw = true

            --[[ Mouse click? --]]
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_UP then
            local x = event.mouse.x
            local y = event.mouse.y
            if x >= ex.BUTTONS_X then
                local button = math.floor(y / 20)
                if button == 2 then ex.image = 0 end
                if button == 3 then ex.image = 1 end
                if button == 4 then ex.image = 2 end
                if button == 5 then ex.image = 3 end
                if button == 6 then ex.image = 4 end
                if button == 7 then ex.image = 5 end

                if button == 10 then ex.mode = 0 end

                if button == 11 then ex.mode = 1 end
                if button == 12 then ex.mode = 2 end
                if button == 13 then ex.mode = 3 end
                if button == 14 then ex.mode = 4 end
                if button == 15 then ex.mode = 5 end

                if button == 16 then ex.mode = 6 end
                if button == 17 then ex.mode = 7 end
                if button == 18 then ex.mode = 8 end
                if button == 19 then ex.mode = 9 end
                if button == 20 then ex.mode = 10 end
            end
        end
    end
end

--[[ Initialize the example. --]]
local function init()
    ex.BUTTONS_X = 40 + 110 * 4
    ex.FPS = 60

    ex.myfont = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/font.tga", 0, 0)
    if not ex.myfont then
        abort_example(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/font.tga not found\n")
    end
    ex.example = create_example_bitmap()

    ex.offscreen = allegro5.al_create_bitmap(640, 480)
    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    ex.memory = allegro5.al_create_bitmap(640, 480)
end

local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_init_primitives_addon()
    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()
    allegro5.al_install_touch_input()
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
    if allegro5.al_is_touch_input_installed() then
        allegro5.al_register_event_source(ex.queue,
            allegro5.al_get_touch_input_mouse_emulation_event_source())
    end

    allegro5.al_start_timer(timer)
    run()

    allegro5.al_destroy_event_queue(ex.queue)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
