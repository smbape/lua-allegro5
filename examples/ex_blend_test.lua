#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_blend_test.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end


local test_only_index = 0
local test_index = 0
local test_display = false
local display

local OPERATIONS = {
    "bitmap",
    "pixel",
    "prim",
}

local function print_color(c)
    local r, g, b, a = allegro5.al_unmap_rgba_f(c)
    log_printf("%.2f, %.2f, %.2f, %.2f", r, g, b, a)
end

local function test(src_col, dst_col,
                    src_format, dst_format,
                    src, dst, src_a, dst_a,
                    operation, verbose)
    allegro5.al_set_new_bitmap_format(dst_format)
    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
    local dst_bmp = allegro5.al_create_bitmap(1, 1)
    allegro5.al_set_target_bitmap(dst_bmp)
    allegro5.al_clear_to_color(dst_col)
    if operation == 0 + INDEX_BASE then
        allegro5.al_set_new_bitmap_format(src_format)
        local src_bmp = allegro5.al_create_bitmap(1, 1)
        allegro5.al_set_target_bitmap(src_bmp)
        allegro5.al_clear_to_color(src_col)
        allegro5.al_set_target_bitmap(dst_bmp)
        allegro5.al_set_separate_blender(allegro5.ALLEGRO_ADD, src, dst, allegro5.ALLEGRO_ADD, src_a, dst_a)
        allegro5.al_draw_bitmap(src_bmp, 0, 0, 0)
        allegro5.al_destroy_bitmap(src_bmp)
    elseif operation == 1 + INDEX_BASE then
        allegro5.al_set_separate_blender(allegro5.ALLEGRO_ADD, src, dst, allegro5.ALLEGRO_ADD, src_a, dst_a)
        allegro5.al_draw_pixel(0, 0, src_col)
    elseif operation == 2 + INDEX_BASE then
        allegro5.al_set_separate_blender(allegro5.ALLEGRO_ADD, src, dst, allegro5.ALLEGRO_ADD, src_a, dst_a)
        allegro5.al_draw_line(0, 0, 1, 1, src_col, 0)
    end

    local result = allegro5.al_get_pixel(dst_bmp, 0, 0)

    allegro5.al_set_target_backbuffer(display)

    if test_display then
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
        allegro5.al_draw_bitmap(dst_bmp, 0, 0, 0)
    end

    allegro5.al_destroy_bitmap(dst_bmp)

    if not verbose then
        return result
    end

    log_printf("---\n")
    log_printf("test id: %d\n", test_index)

    log_printf("source     : ")
    print_color(src_col)
    log_printf(" %s format=%d mode=%d alpha=%d\n",
        OPERATIONS[operation],
        src_format, src, src_a)

    log_printf("destination: ")
    print_color(dst_col)
    log_printf(" format=%d mode=%d alpha=%d\n",
        dst_format, dst, dst_a)

    log_printf("result     : ")
    print_color(result)
    log_printf("\n")

    return result
end

local function same_color(c1, c2)
    local r1, g1, b1, a1 = allegro5.al_unmap_rgba_f(c1)
    local r2, g2, b2, a2 = allegro5.al_unmap_rgba_f(c2)
    local dr = r1 - r2
    local dg = g1 - g2
    local db = b1 - b2
    local da = a1 - a2
    local d = math.sqrt(dr * dr + dg * dg + db * db + da * da)
    return d < 0.01
end

local function get_factor(operation, alpha)
    if operation == allegro5.ALLEGRO_ZERO then
        return 0
    end
    if operation == allegro5.ALLEGRO_ONE then
        return 1
    end
    if operation == allegro5.ALLEGRO_ALPHA then
        return alpha
    end
    if operation == allegro5.ALLEGRO_INVERSE_ALPHA then
        return 1 - alpha
    end
    return 0
end

local function has_alpha(format)
    if format == allegro5.ALLEGRO_PIXEL_FORMAT_RGB_888 then
        return false
    end
    if format == allegro5.ALLEGRO_PIXEL_FORMAT_BGR_888 then
        return false
    end
    return true
end

local function CLAMP(x)
    return x > 1 and 1 or x
end

local function reference_implementation(
    src_col, dst_col,
    src_format, dst_format,
    src_mode, dst_mode, src_alpha, dst_alpha,
    operation)
    local sr, sg, sb, sa = allegro5.al_unmap_rgba_f(src_col)
    local dr, dg, db, da = allegro5.al_unmap_rgba_f(dst_col)

    --[[ Do we even have source alpha? --]]
    if operation == 0 then
        if not has_alpha(src_format) then
            sa = 1
        end
    end

    local r = sr
    local g = sg
    local b = sb
    local a = sa

    local src = get_factor(src_mode, a)
    local dst = get_factor(dst_mode, a)
    local asrc = get_factor(src_alpha, a)
    local adst = get_factor(dst_alpha, a)

    r = r * src + dr * dst
    g = g * src + dg * dst
    b = b * src + db * dst
    a = a * asrc + da * adst

    r = CLAMP(r)
    g = CLAMP(g)
    b = CLAMP(b)
    a = CLAMP(a)

    --[[ Do we even have destination alpha? --]]
    if not has_alpha(dst_format) then
        a = 1
    end

    return allegro5.al_map_rgba_f(r, g, b, a)
end

local function do_test2(src_col, dst_col,
                        src_format, dst_format,
                        src_mode, dst_mode, src_alpha, dst_alpha,
                        operation)
    test_index = test_index + 1

    if test_only_index > 0 and test_index ~= test_only_index then
        return
    end

    local reference = reference_implementation(
        src_col, dst_col, src_format, dst_format,
        src_mode, dst_mode, src_alpha, dst_alpha, operation)

    local result = test(src_col, dst_col, src_format,
        dst_format, src_mode, dst_mode, src_alpha, dst_alpha,
        operation, false)

    if not same_color(reference, result) then
        test(src_col, dst_col, src_format,
            dst_format, src_mode, dst_mode, src_alpha, dst_alpha,
            operation, true)
        log_printf("expected   : ")
        print_color(reference)
        log_printf("\n")
        abort_example("FAILED\n")
    else
        log_printf(" OK")
    end

    if test_display then
        dst_format = allegro5.al_get_display_format(display)
        local from_display = allegro5.al_get_pixel(allegro5.al_get_backbuffer(display), 0, 0)
        reference = reference_implementation(
            src_col, dst_col, src_format, dst_format,
            src_mode, dst_mode, src_alpha, dst_alpha, operation)

        if not same_color(reference, from_display) then
            test(src_col, dst_col, src_format,
                dst_format, src_mode, dst_mode, src_alpha, dst_alpha,
                operation, true)
            log_printf("displayed  : ")
            print_color(from_display)
            log_printf("\n")
            log_printf("expected   : ")
            print_color(reference)
            log_printf("\n")
            abort_example("(FAILED on display)\n")
        end
    end
end

local function do_test1(src_col, dst_col,
                        src_format, dst_format)
    local smodes = { allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_ZERO, allegro5.ALLEGRO_ONE,
        allegro5.ALLEGRO_INVERSE_ALPHA }
    local dmodes = { allegro5.ALLEGRO_INVERSE_ALPHA, allegro5.ALLEGRO_ZERO, allegro5.ALLEGRO_ONE,
        allegro5.ALLEGRO_ALPHA }
    for i = 1, #smodes do
        for j = 1, #dmodes do
            for k = 1, #smodes do
                for l = 1, #dmodes do
                    for m = 1, #OPERATIONS do
                        do_test2(src_col, dst_col,
                            src_format, dst_format,
                            smodes[i], dmodes[j], smodes[k], dmodes[l],
                            m)
                    end
                end
            end
        end
    end
end

local C = allegro5.al_map_rgba_f

local function main(argv)
    local argc = #argv

    local src_colors = {}
    local dst_colors = {}
    local src_formats = {
        allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_8888,
        allegro5.ALLEGRO_PIXEL_FORMAT_BGR_888
    }
    local dst_formats = {
        allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_8888,
        allegro5.ALLEGRO_PIXEL_FORMAT_BGR_888
    }
    src_colors[0 + INDEX_BASE] = C(0, 0, 0, 1)
    src_colors[1 + INDEX_BASE] = C(1, 1, 1, 1)
    dst_colors[0 + INDEX_BASE] = C(1, 1, 1, 1)
    dst_colors[1 + INDEX_BASE] = C(0, 0, 0, 0)

    for i = 1, argc do
        if argv[i] == "-d" then
            test_display = true
        else
            test_only_index = tonumber(argv[i], 10)
        end
    end

    if not allegro5.al_init() then
        abort_example("Could not initialise Allegro\n")
    end

    open_log()

    allegro5.al_init_primitives_addon()
    if test_display then
        display = allegro5.al_create_display(100, 100)
        if not display then
            abort_example("Unable to create display\n")
        end
    end

    for i = 1, #src_colors do
        for j = 1, #dst_colors do
            for l = 1, #src_formats do
                for m = 1, #dst_formats do
                    do_test1(
                        src_colors[i],
                        dst_colors[j],
                        src_formats[l],
                        dst_formats[m])
                end
            end
        end
    end
    log_printf("\nDone\n")

    if test_only_index > 0 and test_display then
        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_flip_display()
        allegro5.al_install_keyboard()
        local queue = allegro5.al_create_event_queue()
        allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
        allegro5.al_wait_for_event(queue, event)
    end

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
