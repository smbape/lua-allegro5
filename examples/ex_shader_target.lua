#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_shader_target.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

local INDEX_BASE = 1 -- lua is 1-based indexed

local ffi = allegro5_lua.ffi

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
    ffi = require("ffi")
end

local new_array = function(ctype, init)
    local cdata

    if type(init) == "table" then
        cdata = ffi.new(ctype .. "[?]", #init, init)
    elseif type(init) == "string" and ctype == "char" then
        cdata = ffi.new(ctype .. "[?]", #init + 1, init)
    else
        cdata = ffi.new(ctype .. "[?]", init)
    end

    return cdata, cdata, ffi.sizeof(cdata) / ffi.sizeof(ctype)
end

--[[
 -    Example program for the Allegro library.
 -
 -    Test that shaders are applied per target bitmap.
 --]]

local MAX_REGION = 4

local tints = new_array("float", {
    4.0, 0.0, 1.0,
    0.0, 4.0, 1.0,
    1.0, 0.0, 4.0,
    4.0, 4.0, 1.0
})

local function choose_shader_source(platform)
    local vsource, psource
    if platform == allegro5.ALLEGRO_SHADER_HLSL then
        vsource = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_shader_vertex.hlsl"
        psource = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_shader_pixel.hlsl"
    elseif platform == allegro5.ALLEGRO_SHADER_GLSL then
        vsource = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_shader_vertex.glsl"
        psource = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_shader_pixel.glsl"
    else
        --[[ Shouldn't happen. --]]
        vsource = nil
        psource = nil
    end
    return vsource, psource
end

local function make_region(parent, x, y, w, h, shader)
    local sub = allegro5.al_create_sub_bitmap(parent, x, y, w, h)
    if sub then
        allegro5.al_set_target_bitmap(sub)
        allegro5.al_use_shader(shader)
        --[[ Not bothering to restore old target bitmap. --]]
    end
    return sub
end

local function main()
    local region = {}

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    allegro5.al_install_keyboard()
    allegro5.al_init_image_addon()
    init_platform_specific()

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_PROGRAMMABLE_PIPELINE)
    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Could not create display.\n")
    end

    local image = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not image then
        abort_example("Could not load image.\n")
    end

    --[[ Create the shader. --]]
    local shader = allegro5.al_create_shader(allegro5.ALLEGRO_SHADER_AUTO)
    if not shader then
        abort_example("Could not create shader.\n")
    end
    local vsource, psource = choose_shader_source(allegro5.al_get_shader_platform(shader))
    if not vsource or not psource then
        abort_example("Could not load source files.\n")
    end
    if not allegro5.al_attach_shader_source_file(shader, allegro5.ALLEGRO_VERTEX_SHADER, vsource) then
        abort_example("al_attach_shader_source_file failed: %s\n",
            allegro5.al_get_shader_log(shader))
    end
    if not allegro5.al_attach_shader_source_file(shader, allegro5.ALLEGRO_PIXEL_SHADER, psource) then
        abort_example("al_attach_shader_source_file failed: %s\n",
            allegro5.al_get_shader_log(shader))
    end
    if not allegro5.al_build_shader(shader) then
        abort_example("al_build_shader failed: %s\n", allegro5.al_get_shader_log(shader))
    end

    --[[ Create four sub-bitmaps of the backbuffer sharing a shader. --]]
    local backbuffer = allegro5.al_get_backbuffer(display)
    region[0 + INDEX_BASE] = make_region(backbuffer, 0, 0, 320, 200, shader)
    region[1 + INDEX_BASE] = make_region(backbuffer, 320, 0, 320, 200, shader)
    region[2 + INDEX_BASE] = make_region(backbuffer, 0, 240, 320, 200, shader)
    region[3 + INDEX_BASE] = make_region(backbuffer, 320, 240, 320, 200, shader)
    if not region[0 + INDEX_BASE] or not region[1 + INDEX_BASE] or not region[2 + INDEX_BASE] or not region[3 + INDEX_BASE] then
        abort_example("make_region failed\n")
    end

    --[[ Apply a transformation to the last region (the current target). --]]
    local t = allegro5.ALLEGRO_TRANSFORM()
    allegro5.al_identity_transform(t)
    allegro5.al_scale_transform(t, 2.0, 2.0)
    allegro5.al_translate_transform(t, -160, -100)
    allegro5.al_use_transform(t)

    while true do
        local s = allegro5.ALLEGRO_KEYBOARD_STATE()
        allegro5.al_get_keyboard_state(s)
        if allegro5.al_key_down(s, allegro5.ALLEGRO_KEY_ESCAPE) then
            break
        end

        for i = 0, MAX_REGION - INDEX_BASE do
            --[[ When we change the target bitmap, the shader that was last used on
          - that bitmap is automatically in effect.  All of our region
          - sub-bitmaps use the same shader so we need to set the tint variable
          - each time, as it was clobbered when drawing to the previous region.
          --]]
            allegro5.al_set_target_bitmap(region[i + INDEX_BASE])
            allegro5.al_set_shader_float_vector("tint", 3, tints + i * 3, 1)
            allegro5.al_draw_bitmap(image, 0, 0, 0)
        end

        allegro5.al_set_target_backbuffer(display)
        allegro5.al_draw_tinted_bitmap(image, allegro5.al_map_rgba_f(0.5, 0.5, 0.5, 0.5),
            320 / 2, 240 / 2, 0)

        allegro5.al_flip_display()
    end

    allegro5.al_set_target_backbuffer(display)
    allegro5.al_use_shader(nil)
    allegro5.al_destroy_shader(shader)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
