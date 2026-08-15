#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_prim.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local pointer_cast = common.pointer_cast
local new_array = common.new_array

local INDEX_BASE = 1 -- lua is 1-based indexed

local cosf = math.cos
local sinf = math.sin
local floor = math.floor

local ffi = allegro5_lua.ffi
local memcpy = allegro5_lua.C.memcpy

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    ffi = require("ffi")
    memcpy = ffi.C.memcpy
else
    ffi.cdef([[
      typedef struct ALLEGRO_COLOR ALLEGRO_COLOR;
      struct ALLEGRO_COLOR
      {
         float r, g, b, a;
      };
   ]])
end

local offsetof = ffi.offsetof
local sizeof = ffi.sizeof

--[[         ______   ___    ___
 -        /\  _  \ /\_ \  /\_ \
 -        \ \ \L\ \\//\ \ \//\ \      __     __   _ __   ___
 -         \ \  __ \ \ \ \  \ \ \   /'__`\ /'_ `\/\`'__\/ __`\
 -          \ \ \/\ \ \_\ \_ \_\ \_/\  __//\ \L\ \ \ \//\ \L\ \
 -           \ \_\ \_\/\____\/\____\ \____\ \____ \ \_\\ \____/
 -            \/_/\/_/\/____/\/____/\/____/\/___L\ \/_/ \/___/
 -                                           /\____/
 -                                           \_/__/
 -
 -      A sampler of the primitive addon.
 -      All primitives are rendered using the additive blender, so overdraw will manifest itself as overly bright pixels.
 -
 -
 -      By Pavel Sountsov.
 -
 -      See readme.txt for copyright information.
 --]]

local ScreenW, ScreenH = 800, 600
local NUM_SCREENS = 14
local ROTATE_SPEED = 0.0100
local Screens = {}
local ScreenName = {}
local Font
local Identity = allegro5.ALLEGRO_TRANSFORM()
local Buffer
local Texture
local solid_white = allegro5.ALLEGRO_COLOR()

local UseShader = false
local Soft = false
local Blend = true
local Speed = ROTATE_SPEED
local Theta = 0
local Background = true
local Thickness = 0
local MainTrans = allegro5.ALLEGRO_TRANSFORM()

local MODE = {
    INIT = 1,
    LOGIC = 2,
    DRAW = 3,
    DEINIT = 4
}

ffi.cdef([[
typedef struct
{
    ALLEGRO_COLOR color;
    short u, v;
    short x, y;
    int junk[6];
} CUSTOM_VERTEX;
]])

local ALLEGRO_COLOR = ffi.typeof("ALLEGRO_COLOR")
local CUSTOM_VERTEX = ffi.typeof("CUSTOM_VERTEX")

local sizeof_ALLEGRO_COLOR = sizeof(ALLEGRO_COLOR)
local sizeof_CUSTOM_VERTEX = sizeof(CUSTOM_VERTEX)
local sizeof_short = sizeof("short")

local CustomVertexFormatPrimitives = (function()
    local vtx = ffi.new("CUSTOM_VERTEX[?]", 4)
    local decl

    local function CustomVertexFormatPrimitives(mode)
        if mode == MODE.INIT then
            local elems = new_array("ALLEGRO_VERTEX_ELEMENT", {
                { allegro5.ALLEGRO_PRIM_POSITION,        allegro5.ALLEGRO_PRIM_SHORT_2, offsetof(CUSTOM_VERTEX, "x") },
                { allegro5.ALLEGRO_PRIM_TEX_COORD_PIXEL, allegro5.ALLEGRO_PRIM_SHORT_2, offsetof(CUSTOM_VERTEX, "u") },
                { allegro5.ALLEGRO_PRIM_COLOR_ATTR,      0,                            offsetof(CUSTOM_VERTEX, "color") },
                { 0,                                    0,                            0 }
            })
            decl = allegro5.al_create_vertex_decl(elems[0], sizeof_CUSTOM_VERTEX)

            for ii = 0, 4 - INDEX_BASE do
                local x = 200 * cosf(ii / 4.0 * 2 * allegro5.ALLEGRO_PI)
                local y = 200 * sinf(ii / 4.0 * 2 * allegro5.ALLEGRO_PI)

                vtx[ii].x = x; vtx[ii].y = y
                vtx[ii].u = 64 * x / 100; vtx[ii].v = 64 * y / 100
                memcpy(vtx[ii].color, allegro5.al_map_rgba_f(1, 1, 1, 1), sizeof_ALLEGRO_COLOR)
            end
        elseif mode == MODE.LOGIC then
            Theta = Theta + Speed
            allegro5.al_build_transform(MainTrans, ScreenW / 2, ScreenH / 2, 1, 1, Theta)
        elseif mode == MODE.DRAW then
            if Blend then
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
            else
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
            end

            allegro5.al_use_transform(MainTrans)

            allegro5.al_draw_prim(vtx, decl, Texture, 0, 4, allegro5.ALLEGRO_PRIM_TRIANGLE_FAN)

            allegro5.al_use_transform(Identity)
        end
    end

    return CustomVertexFormatPrimitives
end)()

local TexturePrimitives = (function()
    local vtx, vtx_ptr = new_array("ALLEGRO_VERTEX", 13)
    local vtx2, vtx2_ptr = new_array("ALLEGRO_VERTEX", 13)

    local function TexturePrimitives(mode)
        if mode == MODE.INIT then
            for ii = 0, 13 - INDEX_BASE do
                local x = 200 * cosf(ii / 13.0 * 2 * allegro5.ALLEGRO_PI)
                local y = 200 * sinf(ii / 13.0 * 2 * allegro5.ALLEGRO_PI)

                local color = allegro5.al_map_rgb((ii + 1) % 3 * 64, (ii + 2) % 3 * 64, (ii) % 3 * 64)

                vtx[ii].x = x; vtx[ii].y = y; vtx[ii].z = 0
                vtx2[ii].x = 0.1 * x; vtx2[ii].y = 0.1 * y
                vtx[ii].u = 64 * x / 100; vtx[ii].v = 64 * y / 100
                vtx2[ii].u = 64 * x / 100; vtx2[ii].v = 64 * y / 100
                if ii < 10 then
                    vtx[ii].color = allegro5.al_map_rgba_f(1, 1, 1, 1)
                else
                    vtx[ii].color = color
                end
                vtx2[ii].color = vtx[ii].color
            end
        elseif mode == MODE.LOGIC then
            Theta = Theta + Speed
            allegro5.al_build_transform(MainTrans, ScreenW / 2, ScreenH / 2, 1, 1, Theta)
        elseif mode == MODE.DRAW then
            if Blend then
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
            else
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
            end

            allegro5.al_use_transform(MainTrans)

            allegro5.al_draw_prim(vtx_ptr, nil, Texture, 0, 4, allegro5.ALLEGRO_PRIM_LINE_LIST)
            allegro5.al_draw_prim(vtx_ptr, nil, Texture, 4, 9, allegro5.ALLEGRO_PRIM_LINE_STRIP)
            allegro5.al_draw_prim(vtx_ptr, nil, Texture, 9, 13, allegro5.ALLEGRO_PRIM_LINE_LOOP)
            allegro5.al_draw_prim(vtx2_ptr, nil, Texture, 0, 13, allegro5.ALLEGRO_PRIM_POINT_LIST)

            allegro5.al_use_transform(Identity)
        end
    end

    return TexturePrimitives
end)()

local FilledTexturePrimitives = (function()
    local vtx, vtx_ptr = new_array("ALLEGRO_VERTEX", 21)

    local function FilledTexturePrimitives(mode)
        if mode == MODE.INIT then
            for ii = 0, 21 - INDEX_BASE do
                local x, y
                local color = allegro5.ALLEGRO_COLOR()
                if ii % 2 == 0 then
                    x = 150 * cosf(ii / 20 * 2 * allegro5.ALLEGRO_PI)
                    y = 150 * sinf(ii / 20 * 2 * allegro5.ALLEGRO_PI)
                else
                    x = 200 * cosf(ii / 20 * 2 * allegro5.ALLEGRO_PI)
                    y = 200 * sinf(ii / 20 * 2 * allegro5.ALLEGRO_PI)
                end

                if ii == 0 then
                    x = 0
                    y = 0
                end

                color = allegro5.al_map_rgb((7 * ii + 1) % 3 * 64, (2 * ii + 2) % 3 * 64, (ii) % 3 * 64)

                vtx[ii].x = x; vtx[ii].y = y; vtx[ii].z = 0
                vtx[ii].u = 64 * x / 100; vtx[ii].v = 64 * y / 100
                if ii < 10 then
                    vtx[ii].color = allegro5.al_map_rgba_f(1, 1, 1, 1)
                else
                    vtx[ii].color = color
                end
            end
        elseif mode == MODE.LOGIC then
            Theta = Theta + Speed
            allegro5.al_build_transform(MainTrans, ScreenW / 2, ScreenH / 2, 1, 1, Theta)
        elseif mode == MODE.DRAW then
            if Blend then
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
            else
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
            end

            allegro5.al_use_transform(MainTrans)

            allegro5.al_draw_prim(vtx_ptr, nil, Texture, 0, 6, allegro5.ALLEGRO_PRIM_TRIANGLE_FAN)
            allegro5.al_draw_prim(vtx_ptr, nil, Texture, 7, 13, allegro5.ALLEGRO_PRIM_TRIANGLE_LIST)
            allegro5.al_draw_prim(vtx_ptr, nil, Texture, 14, 20, allegro5.ALLEGRO_PRIM_TRIANGLE_STRIP)

            allegro5.al_use_transform(Identity)
        end
    end

    return FilledTexturePrimitives
end)()

local FilledPrimitives = (function()
    local vtx, vtx_ptr = new_array("ALLEGRO_VERTEX", 21)

    local function FilledPrimitives(mode)
        if mode == MODE.INIT then
            for ii = 0, 21 - INDEX_BASE do
                local x, y
                local color = allegro5.ALLEGRO_COLOR()
                if ii % 2 == 0 then
                    x = 150 * cosf(ii / 20 * 2 * allegro5.ALLEGRO_PI)
                    y = 150 * sinf(ii / 20 * 2 * allegro5.ALLEGRO_PI)
                else
                    x = 200 * cosf(ii / 20 * 2 * allegro5.ALLEGRO_PI)
                    y = 200 * sinf(ii / 20 * 2 * allegro5.ALLEGRO_PI)
                end

                if ii == 0 then
                    x = 0
                    y = 0
                end

                color = allegro5.al_map_rgb((7 * ii + 1) % 3 * 64, (2 * ii + 2) % 3 * 64, (ii) % 3 * 64)

                vtx[ii].x = x; vtx[ii].y = y; vtx[ii].z = 0
                vtx[ii].color = color
            end
        elseif mode == MODE.LOGIC then
            Theta = Theta + Speed
            allegro5.al_build_transform(MainTrans, ScreenW / 2, ScreenH / 2, 1, 1, Theta)
        elseif mode == MODE.DRAW then
            if Blend then
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
            else
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
            end

            allegro5.al_use_transform(MainTrans)

            allegro5.al_draw_prim(vtx_ptr, nil, nil, 0, 6, allegro5.ALLEGRO_PRIM_TRIANGLE_FAN)
            allegro5.al_draw_prim(vtx_ptr, nil, nil, 7, 13, allegro5.ALLEGRO_PRIM_TRIANGLE_LIST)
            allegro5.al_draw_prim(vtx_ptr, nil, nil, 14, 20, allegro5.ALLEGRO_PRIM_TRIANGLE_STRIP)

            allegro5.al_use_transform(Identity)
        end
    end

    return FilledPrimitives
end)()

local IndexedFilledPrimitives = (function()
    local vtx, vtx_ptr = new_array("ALLEGRO_VERTEX", 21)
    local indices1, indices1_ptr = new_array("int", { 12, 13, 14, 16, 17, 18 })
    local indices2, indices2_ptr = new_array("int", { 6, 7, 8, 9, 10, 11 })
    local indices3, indices3_ptr = new_array("int", { 0, 1, 2, 3, 4, 5 })

    local function IndexedFilledPrimitives(mode)
        if mode == MODE.INIT then
            for ii = 0, 21 - INDEX_BASE do
                local x, y
                local color = allegro5.ALLEGRO_COLOR()
                if ii % 2 == 0 then
                    x = 150 * cosf(ii / 20 * 2 * allegro5.ALLEGRO_PI)
                    y = 150 * sinf(ii / 20 * 2 * allegro5.ALLEGRO_PI)
                else
                    x = 200 * cosf(ii / 20 * 2 * allegro5.ALLEGRO_PI)
                    y = 200 * sinf(ii / 20 * 2 * allegro5.ALLEGRO_PI)
                end

                if ii == 0 then
                    x = 0
                    y = 0
                end

                color = allegro5.al_map_rgb((7 * ii + 1) % 3 * 64, (2 * ii + 2) % 3 * 64, (ii) % 3 * 64)

                vtx[ii].x = x; vtx[ii].y = y; vtx[ii].z = 0
                vtx[ii].color = color
            end
        elseif mode == MODE.LOGIC then
            Theta = Theta + Speed
            for ii = 0, 6 - INDEX_BASE do
                indices1[ii] = floor(allegro5.al_get_time() + ii) % 20 + 1
                indices2[ii] = floor(allegro5.al_get_time() + ii + 6) % 20 + 1
                if ii > 0 then
                    indices3[ii] = floor(allegro5.al_get_time() + ii + 12) % 20 + 1
                end
            end

            allegro5.al_build_transform(MainTrans, ScreenW / 2, ScreenH / 2, 1, 1, Theta)
        elseif mode == MODE.DRAW then
            if Blend then
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
            else
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
            end

            allegro5.al_use_transform(MainTrans)

            allegro5.al_draw_indexed_prim(vtx_ptr, nil, nil, indices1_ptr, 6, allegro5.ALLEGRO_PRIM_TRIANGLE_LIST)
            allegro5.al_draw_indexed_prim(vtx_ptr, nil, nil, indices2_ptr, 6, allegro5.ALLEGRO_PRIM_TRIANGLE_STRIP)
            allegro5.al_draw_indexed_prim(vtx_ptr, nil, nil, indices3_ptr, 6, allegro5.ALLEGRO_PRIM_TRIANGLE_FAN)

            allegro5.al_use_transform(Identity)
        end
    end

    return IndexedFilledPrimitives
end)()

local function HighPrimitives(mode)
    if mode == MODE.INIT then
    elseif mode == MODE.LOGIC then
        Theta = Theta + Speed
        allegro5.al_build_transform(MainTrans, ScreenW / 2, ScreenH / 2, 1, 1, Theta)
    elseif mode == MODE.DRAW then
        local points = new_array("float", {
            -300, -200,
            700, 200,
            -700, 200,
            300, -200
        })

        if Blend then
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
        else
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
        end

        allegro5.al_use_transform(MainTrans)

        allegro5.al_draw_line(-300, -200, 300, 200, allegro5.al_map_rgba_f(0, 0.5, 0.5, 1), Thickness)
        allegro5.al_draw_triangle(-150, -250, 0, 250, 150, -250, allegro5.al_map_rgba_f(0.5, 0, 0.5, 1), Thickness)
        allegro5.al_draw_rectangle(-300, -200, 300, 200, allegro5.al_map_rgba_f(0.5, 0, 0, 1), Thickness)
        allegro5.al_draw_rounded_rectangle(-200, -125, 200, 125, 50, 100, allegro5.al_map_rgba_f(0.2, 0.2, 0, 1), Thickness)

        allegro5.al_draw_ellipse(0, 0, 300, 150, allegro5.al_map_rgba_f(0, 0.5, 0.5, 1), Thickness)
        allegro5.al_draw_elliptical_arc(-20, 0, 300, 200, -allegro5.ALLEGRO_PI / 2, -allegro5.ALLEGRO_PI,
            allegro5.al_map_rgba_f(0.25, 0.25, 0.5, 1), Thickness)
        allegro5.al_draw_arc(0, 0, 200, -allegro5.ALLEGRO_PI / 2, allegro5.ALLEGRO_PI,
            allegro5.al_map_rgba_f(0.5, 0.25, 0, 1),
            Thickness)
        allegro5.al_draw_spline(points, allegro5.al_map_rgba_f(0.1, 0.2, 0.5, 1), Thickness)
        allegro5.al_draw_pieslice(0, 25, 150, allegro5.ALLEGRO_PI * 3 / 4, -allegro5.ALLEGRO_PI / 2,
            allegro5.al_map_rgba_f(0.4, 0.3, 0.1, 1), Thickness)

        allegro5.al_use_transform(Identity)
    end
end

local function HighFilledPrimitives(mode)
    if mode == MODE.INIT then
    elseif mode == MODE.LOGIC then
        Theta = Theta + Speed
        allegro5.al_build_transform(MainTrans, ScreenW / 2, ScreenH / 2, 1, 1, Theta)
    elseif mode == MODE.DRAW then
        if Blend then
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
        else
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
        end
        local _, poly_points = new_array("float", {
            -100, 150,
            0, 80,
            -30, 60,
            -120, 40
        })

        allegro5.al_use_transform(MainTrans)

        allegro5.al_draw_filled_triangle(-100, -200, -110, 0, 50, 20, allegro5.al_map_rgb_f(0.5, 0.7, 0.3))
        allegro5.al_draw_filled_polygon(poly_points, 4, allegro5.al_map_rgb_f(0.8, 0.2, 0.9))
        allegro5.al_draw_filled_rectangle(120, -50, 300, 50, allegro5.al_map_rgb_f(0.3, 0.2, 0.6))
        allegro5.al_draw_filled_ellipse(-250, 0, 100, 150, allegro5.al_map_rgb_f(0.3, 0.3, 0.3))
        allegro5.al_draw_filled_rounded_rectangle(50, -250, 350, -75, 50, 70, allegro5.al_map_rgb_f(0.4, 0.2, 0))
        allegro5.al_draw_filled_pieslice(200, 125, 50, allegro5.ALLEGRO_PI / 4, 3 * allegro5.ALLEGRO_PI / 2,
            allegro5.al_map_rgb_f(0.3, 0.3, 0.1))

        allegro5.al_use_transform(Identity)
    end
end

local HighFilledPrimitivesShader = (function()
    local shader

    local function HighFilledPrimitivesShader(mode)
        if mode == MODE.INIT then
            if not UseShader then
                return
            end
            shader = allegro5.al_create_shader(allegro5.ALLEGRO_SHADER_AUTO)

            if not shader then
                abort_example("Failed to create shader.")
            end

            local vertex_shader_file
            local pixel_shader_file
            if allegro5.al_get_shader_platform(shader) == allegro5.ALLEGRO_SHADER_GLSL then
                vertex_shader_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_prim_high_vertex.glsl"
                pixel_shader_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_prim_high_pixel.glsl"
            else
                vertex_shader_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_prim_high_vertex.hlsl"
                pixel_shader_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_prim_high_pixel.hlsl"
            end

            if not allegro5.al_attach_shader_source_file(shader, allegro5.ALLEGRO_VERTEX_SHADER, vertex_shader_file) then
                abort_example("al_attach_shader_source_file for vertex shader failed: %s\n",
                    allegro5.al_get_shader_log(shader))
            end
            if not allegro5.al_attach_shader_source_file(shader, allegro5.ALLEGRO_PIXEL_SHADER, pixel_shader_file) then
                abort_example("al_attach_shader_source_file for pixel shader failed: %s\n",
                    allegro5.al_get_shader_log(shader))
            end
            if not allegro5.al_build_shader(shader) then
                abort_example("al_build_shader for link failed: %s\n", allegro5.al_get_shader_log(shader))
            end
        elseif mode == MODE.LOGIC then
            Theta = Theta + Speed
            allegro5.al_build_transform(MainTrans, ScreenW / 2, ScreenH / 2, 1, 1, Theta)
        elseif mode == MODE.DRAW then
            if Blend then
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
            else
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
            end

            allegro5.al_use_transform(MainTrans)
            if not UseShader then
                allegro5.al_draw_text(Font, allegro5.al_map_rgb_f(1, 1, 1), 0, -40, 0,
                    "Enable shaders (by using --shader arg)")
            elseif Soft then
                allegro5.al_draw_text(Font, allegro5.al_map_rgb_f(1, 1, 1), 0, -40, 0,
                    "Shaders don't work with software rendering")
            else
                -- float poly_points[8] = {
                --    -100, 150,
                --    0, 80,
                --    -30, 60,
                --    -120, 40
                -- };
                local old_shader = allegro5.al_get_current_shader()
                allegro5.al_use_shader(shader)
                allegro5.al_draw_filled_triangle(-100, -200, -110, 0, 50, 20, allegro5.al_map_rgb_f(0.5, 0.7, 0.3))
                -- al_draw_filled_polygon(poly_points, 4, al_map_rgb_f(0.8, 0.2, 0.9));
                allegro5.al_draw_filled_rectangle(120, -50, 300, 50, allegro5.al_map_rgb_f(0.3, 0.2, 0.6))
                allegro5.al_draw_filled_ellipse(-250, 0, 100, 150, allegro5.al_map_rgb_f(0.3, 0.3, 0.3))
                allegro5.al_draw_filled_rounded_rectangle(50, -250, 350, -75, 50, 70, allegro5.al_map_rgb_f(0.4, 0.2, 0))
                allegro5.al_draw_filled_pieslice(200, 125, 50, allegro5.ALLEGRO_PI / 4, 3 * allegro5.ALLEGRO_PI / 2,
                    allegro5.al_map_rgb_f(0.3, 0.3, 0.1))
                allegro5.al_use_shader(old_shader)
            end
            allegro5.al_use_transform(Identity)
        end
    end

    return HighFilledPrimitivesShader
end)()

local HighPrimitivesShader = (function()
    local shader

    local function HighPrimitivesShader(mode)
        if mode == MODE.INIT then
            if not UseShader then
                return
            end
            shader = allegro5.al_create_shader(allegro5.ALLEGRO_SHADER_AUTO)

            if not shader then
                abort_example("Failed to create shader.")
            end

            local vertex_shader_file
            local pixel_shader_file
            if allegro5.al_get_shader_platform(shader) == allegro5.ALLEGRO_SHADER_GLSL then
                vertex_shader_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_prim_high_vertex.glsl"
                pixel_shader_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_prim_high_pixel.glsl"
            else
                vertex_shader_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_prim_high_vertex.hlsl"
                pixel_shader_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_prim_high_pixel.hlsl"
            end

            if not allegro5.al_attach_shader_source_file(shader, allegro5.ALLEGRO_VERTEX_SHADER, vertex_shader_file) then
                abort_example("al_attach_shader_source_file for vertex shader failed: %s\n",
                    allegro5.al_get_shader_log(shader))
            end
            if not allegro5.al_attach_shader_source_file(shader, allegro5.ALLEGRO_PIXEL_SHADER, pixel_shader_file) then
                abort_example("al_attach_shader_source_file for pixel shader failed: %s\n",
                    allegro5.al_get_shader_log(shader))
            end
            if not allegro5.al_build_shader(shader) then
                abort_example("al_build_shader for link failed: %s\n", allegro5.al_get_shader_log(shader))
            end
        elseif mode == MODE.LOGIC then
            Theta = Theta + Speed
            allegro5.al_build_transform(MainTrans, ScreenW / 2, ScreenH / 2, 1, 1, Theta)
        elseif mode == MODE.DRAW then
            if Blend then
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
            else
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
            end

            allegro5.al_use_transform(MainTrans)
            if not UseShader then
                allegro5.al_draw_text(Font, allegro5.al_map_rgb_f(1, 1, 1), 0, -40, 0,
                    "Enable shaders (by using --shader arg)")
            elseif Soft then
                allegro5.al_draw_text(Font, allegro5.al_map_rgb_f(1, 1, 1), 0, -40, 0,
                    "Shaders don't work with software rendering")
            else
                local old_shader = allegro5.al_get_current_shader()
                allegro5.al_use_shader(shader)
                local points = new_array("float", {
                    -300, -200,
                    700, 200,
                    -700, 200,
                    300, -200
                })

                allegro5.al_draw_line(-300, -200, 300, 200, allegro5.al_map_rgba_f(0, 0.5, 0.5, 1), Thickness)
                allegro5.al_draw_triangle(-150, -250, 0, 250, 150, -250, allegro5.al_map_rgba_f(0.5, 0, 0.5, 1), Thickness)
                allegro5.al_draw_rectangle(-300, -200, 300, 200, allegro5.al_map_rgba_f(0.5, 0, 0, 1), Thickness)
                allegro5.al_draw_rounded_rectangle(-200, -125, 200, 125, 50, 100, allegro5.al_map_rgba_f(0.2, 0.2, 0, 1),
                    Thickness)

                allegro5.al_draw_ellipse(0, 0, 300, 150, allegro5.al_map_rgba_f(0, 0.5, 0.5, 1), Thickness)
                allegro5.al_draw_elliptical_arc(-20, 0, 300, 200, -allegro5.ALLEGRO_PI / 2, -allegro5.ALLEGRO_PI,
                    allegro5.al_map_rgba_f(0.25, 0.25, 0.5, 1), Thickness)
                allegro5.al_draw_arc(0, 0, 200, -allegro5.ALLEGRO_PI / 2, allegro5.ALLEGRO_PI,
                    allegro5.al_map_rgba_f(0.5, 0.25, 0, 1), Thickness)
                allegro5.al_draw_spline(points, allegro5.al_map_rgba_f(0.1, 0.2, 0.5, 1), Thickness)
                allegro5.al_draw_pieslice(0, 25, 150, allegro5.ALLEGRO_PI * 3 / 4, -allegro5.ALLEGRO_PI / 2,
                    allegro5.al_map_rgba_f(0.4, 0.3, 0.1, 1), Thickness)
                allegro5.al_use_shader(old_shader)
            end
            allegro5.al_use_transform(Identity)
        end
    end

    return HighPrimitivesShader
end)()

local function TransformationsPrimitives(mode)
    local t = allegro5.al_get_time()
    if mode == MODE.INIT then
    elseif mode == MODE.LOGIC then
        Theta = Theta + Speed
        allegro5.al_build_transform(MainTrans, ScreenW / 2, ScreenH / 2, sinf(t / 5), cosf(t / 5), Theta)
    elseif mode == MODE.DRAW then
        local points = new_array("float", {
            -300, -200,
            700, 200,
            -700, 200,
            300, -200
        })

        if Blend then
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
        else
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
        end

        allegro5.al_use_transform(MainTrans)

        allegro5.al_draw_line(-300, -200, 300, 200, allegro5.al_map_rgba_f(0, 0.5, 0.5, 1), Thickness)
        allegro5.al_draw_triangle(-150, -250, 0, 250, 150, -250, allegro5.al_map_rgba_f(0.5, 0, 0.5, 1), Thickness)
        allegro5.al_draw_rectangle(-300, -200, 300, 200, allegro5.al_map_rgba_f(0.5, 0, 0, 1), Thickness)
        allegro5.al_draw_rounded_rectangle(-200, -125, 200, 125, 50, 100, allegro5.al_map_rgba_f(0.2, 0.2, 0, 1), Thickness)

        allegro5.al_draw_ellipse(0, 0, 300, 150, allegro5.al_map_rgba_f(0, 0.5, 0.5, 1), Thickness)
        allegro5.al_draw_elliptical_arc(-20, 0, 300, 200, -allegro5.ALLEGRO_PI / 2, -allegro5.ALLEGRO_PI,
            allegro5.al_map_rgba_f(0.25, 0.25, 0.5, 1), Thickness)
        allegro5.al_draw_arc(0, 0, 200, -allegro5.ALLEGRO_PI / 2, allegro5.ALLEGRO_PI,
            allegro5.al_map_rgba_f(0.5, 0.25, 0, 1),
            Thickness)
        allegro5.al_draw_spline(points, allegro5.al_map_rgba_f(0.1, 0.2, 0.5, 1), Thickness)
        allegro5.al_draw_pieslice(0, 25, 150, allegro5.ALLEGRO_PI * 3 / 4, -allegro5.ALLEGRO_PI / 2,
            allegro5.al_map_rgba_f(0.4, 0.3, 0.1, 1), Thickness)

        allegro5.al_use_transform(Identity)
    end
end

local LowPrimitives = (function()
    local vtx, vtx_ptr = new_array("ALLEGRO_VERTEX", 13)
    local vtx2, vtx2_ptr = new_array("ALLEGRO_VERTEX", 13)

    local function LowPrimitives(mode)
        if mode == MODE.INIT then
            for ii = 0, 13 - INDEX_BASE do
                local x = 200 * cosf(ii / 13.0 * 2 * allegro5.ALLEGRO_PI)
                local y = 200 * sinf(ii / 13.0 * 2 * allegro5.ALLEGRO_PI)

                local color = allegro5.al_map_rgb((ii + 1) % 3 * 64, (ii + 2) % 3 * 64, (ii) % 3 * 64)

                vtx[ii].x = x
                vtx[ii].y = y
                vtx[ii].z = 0
                vtx2[ii].x = 0.1 * x
                vtx2[ii].y = 0.1 * y
                vtx[ii].color = color
                vtx2[ii].color = color
            end
        elseif mode == MODE.LOGIC then
            Theta = Theta + Speed
            allegro5.al_build_transform(MainTrans, ScreenW / 2, ScreenH / 2, 1, 1, Theta)
        elseif mode == MODE.DRAW then
            if Blend then
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
            else
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
            end

            allegro5.al_use_transform(MainTrans)

            allegro5.al_draw_prim(vtx_ptr, nil, nil, 0, 4, allegro5.ALLEGRO_PRIM_LINE_LIST)
            allegro5.al_draw_prim(vtx_ptr, nil, nil, 4, 9, allegro5.ALLEGRO_PRIM_LINE_STRIP)
            allegro5.al_draw_prim(vtx_ptr, nil, nil, 9, 13, allegro5.ALLEGRO_PRIM_LINE_LOOP)
            allegro5.al_draw_prim(vtx2_ptr, nil, nil, 0, 13, allegro5.ALLEGRO_PRIM_POINT_LIST)

            allegro5.al_use_transform(Identity)
        end
    end

    return LowPrimitives
end)()

local IndexedPrimitives = (function()
    local indices1, indices1_ptr = new_array("int", { 0, 1, 3, 4 })
    local indices2, indices2_ptr = new_array("int", { 5, 6, 7, 8 })
    local indices3, indices3_ptr = new_array("int", { 9, 10, 11, 12 })
    local vtx, vtx_ptr = new_array("ALLEGRO_VERTEX", 13)
    local vtx2, vtx2_ptr = new_array("ALLEGRO_VERTEX", 13)

    local function IndexedPrimitives(mode)
        if mode == MODE.INIT then
            local color = allegro5.ALLEGRO_COLOR()
            for ii = 0, 13 - INDEX_BASE do
                local x = 200 * cosf(ii / 13.0 * 2 * allegro5.ALLEGRO_PI)
                local y = 200 * sinf(ii / 13.0 * 2 * allegro5.ALLEGRO_PI)

                color = allegro5.al_map_rgb((ii + 1) % 3 * 64, (ii + 2) % 3 * 64, (ii) % 3 * 64)

                vtx[ii].x = x
                vtx[ii].y = y
                vtx[ii].z = 0
                vtx2[ii].x = 0.1 * x
                vtx2[ii].y = 0.1 * y
                vtx[ii].color = color
                vtx2[ii].color = color
            end
        elseif mode == MODE.LOGIC then
            Theta = Theta + Speed
            for ii = 0, 4 - INDEX_BASE do
                indices1[ii] = floor(allegro5.al_get_time() + ii) % 13
                indices2[ii] = floor(allegro5.al_get_time() + ii + 4) % 13
                indices3[ii] = floor(allegro5.al_get_time() + ii + 8) % 13
            end

            allegro5.al_build_transform(MainTrans, ScreenW / 2, ScreenH / 2, 1, 1, Theta)
        elseif mode == MODE.DRAW then
            if Blend then
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
            else
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
            end

            allegro5.al_use_transform(MainTrans)

            allegro5.al_draw_indexed_prim(vtx_ptr, nil, nil, indices1_ptr, 4, allegro5.ALLEGRO_PRIM_LINE_LIST)
            allegro5.al_draw_indexed_prim(vtx_ptr, nil, nil, indices2_ptr, 4, allegro5.ALLEGRO_PRIM_LINE_STRIP)
            allegro5.al_draw_indexed_prim(vtx_ptr, nil, nil, indices3_ptr, 4, allegro5.ALLEGRO_PRIM_LINE_LOOP)
            allegro5.al_draw_indexed_prim(vtx2_ptr, nil, nil, indices3_ptr, 4, allegro5.ALLEGRO_PRIM_POINT_LIST)

            allegro5.al_use_transform(Identity)
        end
    end

    return IndexedPrimitives
end)()

local VertexBuffers = (function()
    local vtx, vtx_ptr = new_array("ALLEGRO_VERTEX", 13)
    local vtx2, vtx2_ptr = new_array("ALLEGRO_VERTEX", 13)
    local vbuff
    local vbuff2
    local no_soft = false
    local no_soft2 = false

    local function VertexBuffers(mode)
        if mode == MODE.INIT then
            local color = allegro5.ALLEGRO_COLOR()
            for ii = 0, 13 - INDEX_BASE do
                local x = 200 * cosf(ii / 13.0 * 2 * allegro5.ALLEGRO_PI)
                local y = 200 * sinf(ii / 13.0 * 2 * allegro5.ALLEGRO_PI)

                color = allegro5.al_map_rgb((ii + 1) % 3 * 64, (ii + 2) % 3 * 64, (ii) % 3 * 64)

                vtx[ii].x = x
                vtx[ii].y = y
                vtx[ii].z = 0
                vtx2[ii].x = 0.1 * x
                vtx2[ii].y = 0.1 * y
                vtx[ii].color = color
                vtx2[ii].color = color
            end
            vbuff = allegro5.al_create_vertex_buffer(nil, vtx_ptr, 13, allegro5.ALLEGRO_PRIM_BUFFER_READWRITE)
            if not vbuff then
                vbuff = allegro5.al_create_vertex_buffer(nil, vtx_ptr, 13, 0)
                no_soft = true
            else
                no_soft = false
            end

            vbuff2 = allegro5.al_create_vertex_buffer(nil, vtx2_ptr, 13, allegro5.ALLEGRO_PRIM_BUFFER_READWRITE)
            if not vbuff2 then
                vbuff2 = allegro5.al_create_vertex_buffer(nil, vtx2_ptr, 13, 0)
                no_soft2 = true
            else
                no_soft2 = false
            end
        elseif mode == MODE.LOGIC then
            Theta = Theta + Speed
            allegro5.al_build_transform(MainTrans, ScreenW / 2, ScreenH / 2, 1, 1, Theta)
        elseif mode == MODE.DRAW then
            if Blend then
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
            else
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
            end

            allegro5.al_use_transform(MainTrans)

            if vbuff and not (Soft and no_soft) then
                allegro5.al_draw_vertex_buffer(vbuff, nil, 0, 4, allegro5.ALLEGRO_PRIM_LINE_LIST)
                allegro5.al_draw_vertex_buffer(vbuff, nil, 4, 9, allegro5.ALLEGRO_PRIM_LINE_STRIP)
                allegro5.al_draw_vertex_buffer(vbuff, nil, 9, 13, allegro5.ALLEGRO_PRIM_LINE_LOOP)
            else
                allegro5.al_draw_text(Font, allegro5.al_map_rgb_f(1, 1, 1), 0, -40, 0, "Vertex buffers not supported")
            end

            if vbuff2 and not (Soft and no_soft2) then
                allegro5.al_draw_vertex_buffer(vbuff2, nil, 0, 13, allegro5.ALLEGRO_PRIM_POINT_LIST)
            else
                allegro5.al_draw_text(Font, allegro5.al_map_rgb_f(1, 1, 1), 0, 40, 0, "Vertex buffers not supported")
            end

            allegro5.al_use_transform(Identity)
        elseif mode == MODE.DEINIT then
            allegro5.al_destroy_vertex_buffer(vbuff)
            allegro5.al_destroy_vertex_buffer(vbuff2)
        end
    end

    return VertexBuffers
end)()

local IndexedBuffers = (function()
    local vbuff
    local ibuff
    local soft = true

    local function IndexedBuffers(mode)
        if mode == MODE.INIT then
            local flags = allegro5.ALLEGRO_PRIM_BUFFER_READWRITE

            vbuff = allegro5.al_create_vertex_buffer(nil, nil, 13, allegro5.ALLEGRO_PRIM_BUFFER_READWRITE)
            if vbuff == nil then
                vbuff = allegro5.al_create_vertex_buffer(nil, nil, 13, 0)
                soft = false
                flags = 0
            end

            ibuff = allegro5.al_create_index_buffer(sizeof_short, nil, 8, flags)

            if vbuff then
                local vtx = pointer_cast("ALLEGRO_VERTEX",
                    allegro5.al_lock_vertex_buffer(vbuff, 0, 13, allegro5.ALLEGRO_LOCK_WRITEONLY))

                for ii = 0, 13 - INDEX_BASE do
                    local x = 200 * cosf(ii / 13.0 * 2 * allegro5.ALLEGRO_PI)
                    local y = 200 * sinf(ii / 13.0 * 2 * allegro5.ALLEGRO_PI)

                    local color = allegro5.al_map_rgb((ii + 1) % 3 * 64, (ii + 2) % 3 * 64, (ii) % 3 * 64)

                    vtx[ii].x = x
                    vtx[ii].y = y
                    vtx[ii].z = 0
                    vtx[ii].color = color
                end

                allegro5.al_unlock_vertex_buffer(vbuff)
            end
        elseif mode == MODE.LOGIC then
            if ibuff then
                local t = floor(allegro5.al_get_time())
                local indices = pointer_cast("short",
                    allegro5.al_lock_index_buffer(ibuff, 0, 8, allegro5.ALLEGRO_LOCK_WRITEONLY))

                for ii = 0, 8 - INDEX_BASE do
                    indices[ii] = (t + ii) % 13
                end
                allegro5.al_unlock_index_buffer(ibuff)
            end

            Theta = Theta + Speed
            allegro5.al_build_transform(MainTrans, ScreenW / 2, ScreenH / 2, 1, 1, Theta)
        elseif mode == MODE.DRAW then
            if Blend then
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
            else
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
            end

            allegro5.al_use_transform(MainTrans)

            if not (Soft and not soft) and vbuff and ibuff then
                allegro5.al_draw_indexed_buffer(vbuff, nil, ibuff, 0, 4, allegro5.ALLEGRO_PRIM_LINE_LIST)
                allegro5.al_draw_indexed_buffer(vbuff, nil, ibuff, 4, 8, allegro5.ALLEGRO_PRIM_LINE_STRIP)
            else
                allegro5.al_draw_text(Font, allegro5.al_map_rgb_f(1, 1, 1), 0, 0, 0, "Indexed buffers not supported")
            end

            allegro5.al_use_transform(Identity)
        elseif mode == MODE.DEINIT then
            allegro5.al_destroy_vertex_buffer(vbuff)
            allegro5.al_destroy_index_buffer(ibuff)
        end
    end

    return IndexedBuffers
end)()

local function main(argv)
    local argc = #argv

    if argc >= 1 then
        if argv[1] == "--shader" then
            UseShader = true
        else
            abort_example("Invalid command line option: %s", argv[1])
        end
    end

    -- Initialize Allegro 5 and addons
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    allegro5.al_init_primitives_addon()
    init_platform_specific()

    if UseShader then
        allegro5.al_set_new_display_flags(allegro5.ALLEGRO_PROGRAMMABLE_PIPELINE)
    end

    -- Create a window to display things on: 640x480 pixels
    local display = allegro5.al_create_display(ScreenW, ScreenH)
    if not display then
        abort_example("Error creating display.\n")
    end

    -- Install the keyboard handler
    if not allegro5.al_install_keyboard() then
        abort_example("Error installing keyboard.\n")
    end

    if not allegro5.al_install_mouse() then
        abort_example("Error installing mouse.\n")
    end

    -- Load a font
    Font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga", 0, 0)
    if not Font then
        abort_example("Error loading \"" .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga\".\n")
    end

    solid_white = allegro5.al_map_rgba_f(1, 1, 1, 1)

    local bkg = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bkg.png")

    allegro5.al_set_new_bitmap_wrap(allegro5.ALLEGRO_BITMAP_WRAP_CLAMP, allegro5.ALLEGRO_BITMAP_WRAP_MIRROR)
    Texture = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/texture.tga")

    -- Make and set some color to draw with
    local black = allegro5.al_map_rgba_f(0.0, 0.0, 0.0, 1.0)

    -- Start the event queue to handle keyboard input and our timer
    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())

    allegro5.al_set_window_title(display, "Primitives Example")

    local function run()
        local refresh_rate = 60
        local frames_done = 0
        local time_diff = allegro5.al_get_time()
        local fixed_timestep = 1.0 / refresh_rate
        local real_time = allegro5.al_get_time()
        local game_time = allegro5.al_get_time()
        local cur_screen = 0
        local done = false
        local clip = false

        local timer = allegro5.al_create_timer(allegro5.ALLEGRO_BPS_TO_SECS(refresh_rate))
        allegro5.al_start_timer(timer)
        local timer_queue = allegro5.al_create_event_queue()
        allegro5.al_register_event_source(timer_queue, allegro5.al_get_timer_event_source(timer))

        local old = allegro5.al_get_new_bitmap_flags()
        allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
        Buffer = allegro5.al_create_bitmap(ScreenW, ScreenH)
        allegro5.al_set_new_bitmap_flags(old)

        allegro5.al_identity_transform(Identity)

        Screens[0 + INDEX_BASE] = LowPrimitives
        Screens[1 + INDEX_BASE] = IndexedPrimitives
        Screens[2 + INDEX_BASE] = HighPrimitives
        Screens[3 + INDEX_BASE] = TransformationsPrimitives
        Screens[4 + INDEX_BASE] = FilledPrimitives
        Screens[5 + INDEX_BASE] = IndexedFilledPrimitives
        Screens[6 + INDEX_BASE] = HighFilledPrimitives
        Screens[7 + INDEX_BASE] = TexturePrimitives
        Screens[8 + INDEX_BASE] = FilledTexturePrimitives
        Screens[9 + INDEX_BASE] = CustomVertexFormatPrimitives
        Screens[10 + INDEX_BASE] = VertexBuffers
        Screens[11 + INDEX_BASE] = IndexedBuffers
        Screens[12 + INDEX_BASE] = HighPrimitivesShader
        Screens[13 + INDEX_BASE] = HighFilledPrimitivesShader

        ScreenName[0 + INDEX_BASE] = "Low Level Primitives"
        ScreenName[1 + INDEX_BASE] = "Indexed Primitives"
        ScreenName[2 + INDEX_BASE] = "High Level Primitives"
        ScreenName[3 + INDEX_BASE] = "Transformations"
        ScreenName[4 + INDEX_BASE] = "Low Level Filled Primitives"
        ScreenName[5 + INDEX_BASE] = "Indexed Filled Primitives"
        ScreenName[6 + INDEX_BASE] = "High Level Filled Primitives"
        ScreenName[7 + INDEX_BASE] = "Textured Primitives"
        ScreenName[8 + INDEX_BASE] = "Filled Textured Primitives"
        ScreenName[9 + INDEX_BASE] = "Custom Vertex Format"
        ScreenName[10 + INDEX_BASE] = "Vertex Buffers"
        ScreenName[11 + INDEX_BASE] = "Indexed Buffers"
        ScreenName[12 + INDEX_BASE] = "High Level Primitives + Shaders"
        ScreenName[13 + INDEX_BASE] = "High Level Filled Primitives + Shaders"

        for ii = 0, NUM_SCREENS - INDEX_BASE do
            Screens[ii + INDEX_BASE](MODE.INIT)
            Screens[ii + INDEX_BASE](MODE.LOGIC)
        end

        while not done do
            local frame_duration = allegro5.al_get_time() - real_time
            allegro5.al_rest(fixed_timestep - frame_duration) --rest at least fixed_dt
            frame_duration = allegro5.al_get_time() - real_time
            real_time = allegro5.al_get_time()

            if real_time - game_time > frame_duration then --eliminate excess overflow
                game_time = game_time + fixed_timestep * floor((real_time - game_time) / fixed_timestep)
            end

            while real_time - game_time >= 0 do
                local key_event = allegro5.ALLEGRO_EVENT()
                local start_time = allegro5.al_get_time()
                game_time = game_time + fixed_timestep

                Screens[cur_screen + INDEX_BASE](MODE.LOGIC)

                while allegro5.al_get_next_event(queue, key_event) do
                    if key_event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
                        cur_screen = cur_screen + 1
                        if cur_screen >= NUM_SCREENS then
                            cur_screen = 0
                        end
                    elseif key_event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
                        done = true
                    elseif key_event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
                        if key_event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                            done = true
                        elseif key_event.keyboard.keycode == allegro5.ALLEGRO_KEY_S then
                            Soft = not Soft
                            time_diff = allegro5.al_get_time()
                            frames_done = 0
                        elseif key_event.keyboard.keycode == allegro5.ALLEGRO_KEY_C then
                            clip = not clip
                            time_diff = allegro5.al_get_time()
                            frames_done = 0
                        elseif key_event.keyboard.keycode == allegro5.ALLEGRO_KEY_L then
                            Blend = not Blend
                            time_diff = allegro5.al_get_time()
                            frames_done = 0
                        elseif key_event.keyboard.keycode == allegro5.ALLEGRO_KEY_B then
                            Background = not Background
                            time_diff = allegro5.al_get_time()
                            frames_done = 0
                        elseif key_event.keyboard.keycode == allegro5.ALLEGRO_KEY_LEFT then
                            Speed = Speed - ROTATE_SPEED
                        elseif key_event.keyboard.keycode == allegro5.ALLEGRO_KEY_RIGHT then
                            Speed = Speed + ROTATE_SPEED
                        elseif key_event.keyboard.keycode == allegro5.ALLEGRO_KEY_PGUP then
                            Thickness = Thickness + 0.5
                            if Thickness < 1.0 then
                                Thickness = 1.0
                            end
                        elseif key_event.keyboard.keycode == allegro5.ALLEGRO_KEY_PGDN then
                            Thickness = Thickness - 0.5
                            if Thickness < 1.0 then
                                Thickness = 0.0
                            end
                        elseif key_event.keyboard.keycode == allegro5.ALLEGRO_KEY_UP then
                            cur_screen = cur_screen + 1
                            if cur_screen >= NUM_SCREENS then
                                cur_screen = 0
                            end
                        elseif key_event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
                            Speed = 0
                        elseif key_event.keyboard.keycode == allegro5.ALLEGRO_KEY_DOWN then
                            cur_screen = cur_screen - 1
                            if cur_screen < 0 then
                                cur_screen = NUM_SCREENS - 1
                            end
                        end
                    end
                end

                if allegro5.al_get_time() - start_time >= fixed_timestep then --break if we start taking too long
                    break
                end
            end

            allegro5.al_clear_to_color(black)

            if Soft then
                allegro5.al_set_target_bitmap(Buffer)
                allegro5.al_clear_to_color(black)
            end

            if Background and bkg then
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
                allegro5.al_draw_scaled_bitmap(bkg, 0, 0, allegro5.al_get_bitmap_width(bkg),
                    allegro5.al_get_bitmap_height(bkg),
                    0, 0, ScreenW, ScreenH, 0)
            end

            if clip then
                allegro5.al_set_clipping_rectangle(ScreenW / 2, ScreenH / 2, ScreenW / 2, ScreenH / 2)
            end

            Screens[cur_screen + INDEX_BASE](MODE.DRAW)

            allegro5.al_set_clipping_rectangle(0, 0, ScreenW, ScreenH)

            if Soft then
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
                allegro5.al_set_target_backbuffer(display)
                allegro5.al_draw_bitmap(Buffer, 0, 0, 0)
            end

            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
            allegro5.al_draw_textf(Font, solid_white, ScreenW / 2, ScreenH - 20, allegro5.ALLEGRO_ALIGN_CENTRE, "%s",
                ScreenName[cur_screen + INDEX_BASE])
            allegro5.al_draw_textf(Font, solid_white, 0, 0, 0, "FPS: %f",
                frames_done / (allegro5.al_get_time() - time_diff))
            allegro5.al_draw_textf(Font, solid_white, 0, 20, 0, "Change Screen (Up/Down). Esc to Quit.")
            allegro5.al_draw_textf(Font, solid_white, 0, 40, 0, "Rotation (Left/Right/Space): %f", Speed)
            allegro5.al_draw_textf(Font, solid_white, 0, 60, 0, "Thickness (PgUp/PgDown): %f", Thickness)
            allegro5.al_draw_textf(Font, solid_white, 0, 80, 0, "Software (S): %s", tostring(Soft))
            allegro5.al_draw_textf(Font, solid_white, 0, 100, 0, "Blending (L): %s", tostring(Blend))
            allegro5.al_draw_textf(Font, solid_white, 0, 120, 0, "Background (B): %s", tostring(Background))
            allegro5.al_draw_textf(Font, solid_white, 0, 140, 0, "Clip (C): %s", tostring(clip))

            allegro5.al_flip_display()
            frames_done = frames_done + 1
        end

        for ii = 0, NUM_SCREENS - INDEX_BASE do
            Screens[ii + INDEX_BASE](MODE.DEINIT)
        end

        if allegro5.al_is_system_installed() then
            allegro5.al_uninstall_system()
        end
    end

    run()
end

main(rawget(_G, "arg") or {})
