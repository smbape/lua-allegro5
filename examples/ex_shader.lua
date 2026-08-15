#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_shader.cpp
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local new_array = common.new_array
local pointer_cast = common.pointer_cast

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ The ALLEGRO_CFG_* defines are actually internal to Allegro so don't use them
 - in your own programs.
 --]]

local display_flags = 0

local function parse_args(argc, argv)
    for i = 1, argc do
        local continue = false
        if argv[i] == "--opengl" then
            display_flags = allegro5.ALLEGRO_OPENGL
            continue = true
        elseif allegro5.ALLEGRO_CFG_D3D then
            if argv[i] == "--d3d" then
                display_flags = allegro5.ALLEGRO_DIRECT3D
                continue = true
            end
        end
        if not continue then
            abort_example("Unrecognised argument: %s\n", argv[i])
        end
    end
end

local function choose_shader_source(shader, vsource, psource)
    local platform = allegro5.al_get_shader_platform(shader)
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

local function main(argv)
    local argc = #argv

    parse_args(argc, argv)

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    allegro5.al_install_keyboard()
    allegro5.al_init_image_addon()
    init_platform_specific()

    allegro5.al_set_new_display_flags(bit.bor(allegro5.ALLEGRO_PROGRAMMABLE_PIPELINE, display_flags))

    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Could not create display.\n")
    end

    local bmp = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not bmp then
        abort_example("Could not load bitmap.\n")
    end

    local shader = allegro5.al_create_shader(allegro5.ALLEGRO_SHADER_AUTO)
    if not shader then
        abort_example("Could not create shader.\n")
    end

    local vsource, psource = choose_shader_source(shader)
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

    allegro5.al_use_shader(shader)

    local tints_vector, tints_ptr = new_array("float", {
        4.0, 0.0, 1.0,
        0.0, 4.0, 1.0,
        1.0, 0.0, 4.0,
        4.0, 4.0, 1.0
    })
    local tints = pointer_cast("float", tints_ptr)

    while 1 do
        local s = allegro5.ALLEGRO_KEYBOARD_STATE()
        allegro5.al_get_keyboard_state(s)
        if allegro5.al_key_down(s, allegro5.ALLEGRO_KEY_ESCAPE) then
            break
        end

        allegro5.al_clear_to_color(allegro5.al_map_rgb(140, 40, 40))

        allegro5.al_set_shader_float_vector("tint", 3, tints + 0, 1)
        allegro5.al_draw_bitmap(bmp, 0, 0, 0)

        allegro5.al_set_shader_float_vector("tint", 3, tints + 3, 1)
        allegro5.al_draw_bitmap(bmp, 320, 0, 0)

        allegro5.al_set_shader_float_vector("tint", 3, tints + 6, 1)
        allegro5.al_draw_bitmap(bmp, 0, 240, 0)

        --[[ Draw the last one transformed --]]
        local trans, backup = allegro5.ALLEGRO_TRANSFORM(), allegro5.ALLEGRO_TRANSFORM()
        allegro5.al_copy_transform(backup, allegro5.al_get_current_transform())
        allegro5.al_identity_transform(trans)
        allegro5.al_translate_transform(trans, 320, 240)
        allegro5.al_set_shader_float_vector("tint", 3, tints + 9, 1)
        allegro5.al_use_transform(trans)
        allegro5.al_draw_bitmap(bmp, 0, 0, 0)
        allegro5.al_use_transform(backup)

        allegro5.al_flip_display()

        allegro5.al_rest(0.01)
    end

    allegro5.al_use_shader(nil)
    allegro5.al_destroy_shader(shader)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
