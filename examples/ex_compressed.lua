#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_compressed.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local function main(argv)
    local argc = #argv

    local filename
    local redraw = true
    local cur_bitmap = 0 + INDEX_BASE
    local compare = false
    local NUM_BITMAPS = 4
    local bitmaps = {
        { format = allegro5.ALLEGRO_PIXEL_FORMAT_ANY,                  name = "Uncompressed" },
        { format = allegro5.ALLEGRO_PIXEL_FORMAT_COMPRESSED_RGBA_DXT1, name = "DXT1" },
        { format = allegro5.ALLEGRO_PIXEL_FORMAT_COMPRESSED_RGBA_DXT3, name = "DXT3" },
        { format = allegro5.ALLEGRO_PIXEL_FORMAT_COMPRESSED_RGBA_DXT5, name = "DXT5" },
    }

    if argc >= 1 then
        filename = argv[1]
    else
        filename = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx"
    end

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    if argc >= 2 then
        allegro5.al_set_new_display_adapter(tonumber(argv[2], 10))
    end

    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    allegro5.al_install_keyboard()

    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Error creating display\n")
    end

    for ii = 1, NUM_BITMAPS do
        local t0
        local t1
        allegro5.al_set_new_bitmap_format(bitmaps[ii].format)

        --[[ Load --]]
        t0 = allegro5.al_get_time()
        bitmaps[ii].bmp = allegro5.al_load_bitmap(filename)
        t1 = allegro5.al_get_time()

        if not bitmaps[ii].bmp then
            abort_example("%s not found or failed to load\n", filename)
        end
        log_printf("%s load time: %f sec\n", bitmaps[ii].name, t1 - t0)

        --[[ Clone --]]
        t0 = allegro5.al_get_time()
        bitmaps[ii].clone = allegro5.al_clone_bitmap(bitmaps[ii].bmp)
        t1 = allegro5.al_get_time()

        if not bitmaps[ii].clone then
            abort_example("Couldn't clone %s\n", bitmaps[ii].name)
        end
        log_printf("%s clone time: %f sec\n", bitmaps[ii].name, t1 - t0)

        --[[ Decompress --]]
        allegro5.al_set_new_bitmap_format(allegro5.ALLEGRO_PIXEL_FORMAT_ANY)
        t0 = allegro5.al_get_time()
        bitmaps[ii].decomp = allegro5.al_clone_bitmap(bitmaps[ii].bmp)
        t1 = allegro5.al_get_time()

        if not bitmaps[ii].decomp then
            abort_example("Couldn't decompress %s\n", bitmaps[ii].name)
        end
        log_printf("%s decompress time: %f sec\n", bitmaps[ii].name, t1 - t0)

        --[[ RW lock --]]
        allegro5.al_set_new_bitmap_format(bitmaps[ii].format)
        bitmaps[ii].lock_clone = allegro5.al_clone_bitmap(bitmaps[ii].bmp)

        if not bitmaps[ii].lock_clone then
            abort_example("Couldn't clone %s\n", bitmaps[ii].name)
        end

        if allegro5.al_get_bitmap_width(bitmaps[ii].bmp) > 128
            and allegro5.al_get_bitmap_height(bitmaps[ii].bmp) > 128 then
            local bitmap_format = allegro5.al_get_bitmap_format(bitmaps[ii].bmp)
            local block_width = allegro5.al_get_pixel_block_width(bitmap_format)
            local block_height = allegro5.al_get_pixel_block_height(bitmap_format)

            --[[ Lock and unlock it, hopefully causing a no-op operation --]]
            allegro5.al_lock_bitmap_region_blocked(bitmaps[ii].lock_clone,
                16 / block_width, 16 / block_height, 64 / block_width,
                64 / block_height, allegro5.ALLEGRO_LOCK_READWRITE)

            allegro5.al_unlock_bitmap(bitmaps[ii].lock_clone)
        end
    end

    local bkg = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bkg.png")
    if not bkg then
        abort_example(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bkg.png not found or failed to load\n")
    end

    allegro5.al_set_new_bitmap_format(allegro5.ALLEGRO_PIXEL_FORMAT_ANY)
    local font = allegro5.al_create_builtin_font()
    local timer = allegro5.al_create_timer(1.0 / 30)
    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_start_timer(timer)

    while true do
        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_LEFT then
                cur_bitmap = (cur_bitmap - INDEX_BASE - 1 + NUM_BITMAPS) % NUM_BITMAPS + INDEX_BASE
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_RIGHT then
                cur_bitmap = (cur_bitmap - INDEX_BASE + 1) % NUM_BITMAPS + INDEX_BASE
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
                compare = true
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_UP then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
                compare = false
            end
        end

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            local w = allegro5.al_get_bitmap_width(bitmaps[cur_bitmap].bmp)
            local h = allegro5.al_get_bitmap_height(bitmaps[cur_bitmap].bmp)
            local idx = (function() if compare then return 0 + INDEX_BASE else return cur_bitmap end end)()
            redraw = false
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))
            allegro5.al_draw_bitmap(bkg, 0, 0, 0)
            allegro5.al_draw_textf(font, allegro5.al_map_rgb_f(1, 1, 1), 5, 5, allegro5.ALLEGRO_ALIGN_LEFT,
                "SPACE to compare. Arrows to switch. Format: %s", bitmaps[idx].name)
            allegro5.al_draw_bitmap(bitmaps[idx].bmp, 0, 20, 0)
            allegro5.al_draw_bitmap(bitmaps[idx].clone, w, 20, 0)
            allegro5.al_draw_bitmap(bitmaps[idx].decomp, 0, 20 + h, 0)
            allegro5.al_draw_bitmap(bitmaps[idx].lock_clone, w, 20 + h, 0)
            allegro5.al_flip_display()
        end
    end

    allegro5.al_destroy_bitmap(bkg)
    for ii = 1, NUM_BITMAPS do
        allegro5.al_destroy_bitmap(bitmaps[ii].bmp)
    end

    close_log(false)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
