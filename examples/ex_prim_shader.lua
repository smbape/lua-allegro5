#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_prim_shader.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local new_array = common.new_array

local INDEX_BASE = 1 -- lua is 1-based indexed

local cosf = math.cos
local sinf = math.sin
local sqrtf = math.sqrt
local floor = math.floor

local ffi = allegro5_lua.ffi

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
    ffi = require("ffi")
end

local offsetof = ffi.offsetof
local sizeof = ffi.sizeof

ffi.cdef([[
typedef struct CUSTOM_VERTEX
{
   float x, y;
   float nx, ny, nz;
} CUSTOM_VERTEX;
]])

local CUSTOM_VERTEX = ffi.typeof("CUSTOM_VERTEX")

local RING_SIZE = 25
local SPHERE_RADIUS = 150.1
local SCREEN_WIDTH = 640
local SCREEN_HEIGHT = 480
local NUM_RINGS = floor(SCREEN_WIDTH / RING_SIZE) + 1
local NUM_SEGMENTS = 64
local NUM_VERTICES = NUM_RINGS * NUM_SEGMENTS * 6
local FIRST_OUTSIDE_RING = floor(SPHERE_RADIUS / RING_SIZE)

local function setup_vertex(vtx, ring, segment, inside)
    local len = 0
    local x, y, z = 0, 0, 0
    x = ring * RING_SIZE * cosf(2 * allegro5.ALLEGRO_PI * segment / NUM_SEGMENTS)
    y = ring * RING_SIZE * sinf(2 * allegro5.ALLEGRO_PI * segment / NUM_SEGMENTS)
    vtx.x = x + SCREEN_WIDTH / 2
    vtx.y = y + SCREEN_HEIGHT / 2

    if inside then
        --[[ This comes from the definition of the normal vector as the
       - gradient of the 3D surface. --]]
        z = sqrtf(SPHERE_RADIUS * SPHERE_RADIUS - x * x - y * y)
        vtx.nx = x / z
        vtx.ny = y / z
    else
        vtx.nx = 0
        vtx.ny = 0
    end
    vtx.nz = 1.0

    len = sqrtf(vtx.nx * vtx.nx + vtx.ny * vtx.ny + vtx.nz * vtx.nz)
    vtx.nx = vtx.nx / len
    vtx.ny = vtx.ny / len
    vtx.nz = vtx.nz / len
end

local function main()
    local redraw = true
    local vertex_elems = new_array("ALLEGRO_VERTEX_ELEMENT", {
        { allegro5.ALLEGRO_PRIM_POSITION,  allegro5.ALLEGRO_PRIM_FLOAT_2, offsetof(CUSTOM_VERTEX, "x") },
        { allegro5.ALLEGRO_PRIM_USER_ATTR, allegro5.ALLEGRO_PRIM_FLOAT_3, offsetof(CUSTOM_VERTEX, "nx") },
        { 0,                              0,                            0 }
    })
    local vertices = ffi.new("CUSTOM_VERTEX[?]", NUM_VERTICES)
    local quit = false
    local vertex_shader_file
    local pixel_shader_file
    local vertex_idx = 0
    local diffuse_color, diffuse_color_ptr = new_array("float", { 0.1, 0.1, 0.7, 1.0 })
    local light_position, light_position_ptr = new_array("float", { 0, 0, 100 })

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_install_mouse()
    allegro5.al_install_keyboard()
    allegro5.al_install_touch_input()
    if not allegro5.al_init_primitives_addon() then
        abort_example("Could not init primitives addon.\n")
    end
    init_platform_specific()
    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_PROGRAMMABLE_PIPELINE)
    local display = allegro5.al_create_display(SCREEN_WIDTH, SCREEN_HEIGHT)
    if not display then
        abort_example("Error creating display.\n")
    end

    local vertex_decl = allegro5.al_create_vertex_decl(vertex_elems[0], sizeof(CUSTOM_VERTEX))
    if not vertex_decl then
        abort_example("Error creating vertex declaration.\n")
    end

    --[[ Computes a "spherical" bump ring. The z coordinate is not actually set
    - appropriately as this is a 2D example, but the normal vectors are computed
    - correctly for the light shading effect. --]]
    for ring = 0, NUM_RINGS - INDEX_BASE do
        for segment = 0, NUM_SEGMENTS - INDEX_BASE do
            local inside = ring < FIRST_OUTSIDE_RING
            setup_vertex(vertices[vertex_idx + 0], ring + 0, segment + 0, inside)
            setup_vertex(vertices[vertex_idx + 1], ring + 0, segment + 1, inside)
            setup_vertex(vertices[vertex_idx + 2], ring + 1, segment + 0, inside)
            setup_vertex(vertices[vertex_idx + 3], ring + 1, segment + 0, inside)
            setup_vertex(vertices[vertex_idx + 4], ring + 0, segment + 1, inside)
            setup_vertex(vertices[vertex_idx + 5], ring + 1, segment + 1, inside)
            vertex_idx = vertex_idx + 6
        end
    end

    local shader = allegro5.al_create_shader(allegro5.ALLEGRO_SHADER_AUTO)

    if not shader then
        abort_example("Failed to create shader.")
    end

    if allegro5.al_get_shader_platform(shader) == allegro5.ALLEGRO_SHADER_GLSL then
        vertex_shader_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_prim_shader_vertex.glsl"
        pixel_shader_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_prim_shader_pixel.glsl"
    else
        vertex_shader_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_prim_shader_vertex.hlsl"
        pixel_shader_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_prim_shader_pixel.hlsl"
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

    allegro5.al_use_shader(shader)
    allegro5.al_set_shader_float_vector("diffuse_color", 4, diffuse_color_ptr, 1)
    --[[ alpha controls shininess, and 25 is very shiny --]]
    allegro5.al_set_shader_float("alpha", 25)

    local timer = allegro5.al_create_timer(1.0 / 60)
    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    if allegro5.al_is_touch_input_installed() then
        allegro5.al_register_event_source(queue,
            allegro5.al_get_touch_input_mouse_emulation_event_source())
    end
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_start_timer(timer)

    while not quit do
        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_wait_for_event(queue, event)


        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            quit = true
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_AXES then
            light_position[0] = event.mouse.x
            light_position[1] = event.mouse.y
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                quit = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        end


        if redraw and allegro5.al_is_event_queue_empty(queue) then
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))

            allegro5.al_set_shader_float_vector("light_position", 3, light_position_ptr, 1)
            allegro5.al_draw_prim(vertices, vertex_decl, nil, 0, NUM_VERTICES, allegro5.ALLEGRO_PRIM_TRIANGLE_LIST)

            allegro5.al_flip_display()
            redraw = false
        end
    end

    allegro5.al_use_shader(nil)
    allegro5.al_destroy_shader(shader)
    allegro5.al_destroy_vertex_decl(vertex_decl)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
