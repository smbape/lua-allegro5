#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_drawpixels.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf
local rand = common.rand

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local WIDTH = 640
local HEIGHT = 480
local NUM_STARS = 300
local TARGET_FPS = 9999


---@class Point
---@field x number
---@field y number
---@overload fun(): Point
local function Point()
    return {
        x = 0,
        y = 0,
    }
end

local function main()
    local key_state = allegro5.ALLEGRO_KEYBOARD_STATE()
    local stars = (function()
        local starts = {} ---@type Point[][]

        for i = 1, 3 do
            starts[i] = {}
            for j = 1, NUM_STARS / 3 do
                starts[i][j] = Point()
            end
        end

        return starts
    end)()
    local speeds = { 0.0001, 0.05, 0.15 }
    local colors = { allegro5.ALLEGRO_COLOR(), allegro5.ALLEGRO_COLOR(), allegro5.ALLEGRO_COLOR() }
    local total_frames = 0

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    allegro5.al_install_keyboard()

    local display = allegro5.al_create_display(WIDTH, HEIGHT)
    if not display then
        abort_example("Could not create display.\n")
    end

    colors[0 + INDEX_BASE] = allegro5.al_map_rgba(255, 100, 255, 128)
    colors[1 + INDEX_BASE] = allegro5.al_map_rgba(255, 100, 100, 255)
    colors[2 + INDEX_BASE] = allegro5.al_map_rgba(100, 100, 255, 255)

    for layer = 1, 3 do
        for star = 1, NUM_STARS / 3 do
            local p = stars[layer][star] ---@type Point
            p.x = rand() % WIDTH
            p.y = rand() % HEIGHT
        end
    end


    local start = allegro5.al_get_time() * 1000
    local now = start
    local elapsed = 0
    local frame_count = 0
    local program_start = allegro5.al_get_time()


    while true do
        if frame_count < (1000 / TARGET_FPS) then
            frame_count = frame_count + elapsed
        else
            frame_count = frame_count - (1000 / TARGET_FPS)
            allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))
            for star = 1, NUM_STARS / 3 do
                local p = stars[0 + INDEX_BASE][star]
                allegro5.al_draw_pixel(p.x, p.y, colors[0 + INDEX_BASE])
            end
            allegro5.al_lock_bitmap(allegro5.al_get_backbuffer(display), allegro5.ALLEGRO_PIXEL_FORMAT_ANY, 0)

            for layer = 2, 3 do
                for star = 1, NUM_STARS / 3 do
                    local p = stars[layer][star]
                    -- put_pixel ignores blending
                    allegro5.al_put_pixel(p.x, p.y, colors[layer])
                end
            end

            --[[ Check that dots appear at the window extremes. --]]
            local X = WIDTH - 1
            local Y = HEIGHT - 1
            allegro5.al_put_pixel(0, 0, allegro5.al_map_rgb_f(1, 1, 1))
            allegro5.al_put_pixel(X, 0, allegro5.al_map_rgb_f(1, 1, 1))
            allegro5.al_put_pixel(0, Y, allegro5.al_map_rgb_f(1, 1, 1))
            allegro5.al_put_pixel(X, Y, allegro5.al_map_rgb_f(1, 1, 1))

            allegro5.al_unlock_bitmap(allegro5.al_get_backbuffer(display))
            allegro5.al_flip_display()
            total_frames = total_frames + 1
        end

        now = allegro5.al_get_time() * 1000
        elapsed = now - start
        start = now

        if elapsed > 100 then
            log_printf(string.format("skip due to cpu throttle (%s)\n", elapsed))
        else
            for layer = 1, 3 do
                for star = 1, NUM_STARS / 3 do
                    local p = stars[layer][star]
                    p.y = p.y - speeds[layer] * elapsed
                    if p.y < 0 then
                        p.x = rand() % WIDTH
                        p.y = HEIGHT
                    end
                end
            end
        end

        allegro5.al_rest(0.001)

        allegro5.al_get_keyboard_state(key_state)
        if allegro5.al_key_down(key_state, allegro5.ALLEGRO_KEY_ESCAPE) then
            break
        end
    end

    local length = allegro5.al_get_time() - program_start

    if length ~= 0 then
        log_printf("%d FPS\n", math.floor(total_frames / length))
    end

    allegro5.al_destroy_display(display)

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
