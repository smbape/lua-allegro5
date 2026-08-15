#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_camera.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local init_platform_specific = common.init_platform_specific
local close_log = common.close_log
local log_printf = common.log_printf
local copy = common.copy
local pointer_cast = common.pointer_cast

local INDEX_BASE = 1 -- lua is 1-based indexed

local atan2 = math.atan2 or math.atan ---@diagnostic disable-line: deprecated
local sqrt = math.sqrt
local tan = math.tan
local asin = math.asin

local sizeof = function(data)
    return data.__sizeof
end

local realloc = allegro5_lua.C.realloc

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    realloc = ffi.C.realloc
    sizeof = ffi.sizeof
end

--[[ An example demonstrating how to use ALLEGRO_TRANSFORM to represent a 3D
 - camera.
 --]]

local pi = allegro5.ALLEGRO_PI

local function Vector(initializer_list)
    if initializer_list == nil then
        initializer_list = { 0, 0, 0}
    end

    return {
        x = initializer_list[1],
        y = initializer_list[2],
        z = initializer_list[3],
    }
end

local function Camera()
    return {
        position = Vector(),
        xaxis = Vector(), --[[ This represent the direction looking to the right. --]]
        yaxis = Vector(), --[[ This is the up direction. --]]
        zaxis = Vector(), --[[ This is the direction towards the viewer ('backwards'). --]]
        vertical_field_of_view = 0, --[[ In radians. --]]
    }
end

local function Example()
    return {
        camera = Camera(),

        --[[ controls sensitivity --]]
        mouse_look_speed = 0,
        movement_speed = 0,

        --[[ keyboard and mouse state --]]
        button = {},
        key = {},
        keystate = {},
        mouse_dx = 0,
        mouse_dy = 0,

        --[[ control scheme selection --]]
        controls = 0,
        controls_names = {},

        --[[ the vertex data --]]
        n = 0,
        v_size = 0,
        v = nil,

        --[[ used to draw some info text --]]
        font = nil,

        --[[ if not NULL the skybox picture to use --]]
        skybox = nil,
    }
end

local ex = Example()

--[[ Calculate the dot product between two vectors. This corresponds to the
 - angle between them times their lengths.
 --]]
local function vector_dot_product(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

--[[ Calculate the cross product of two vectors. This produces a normal to the
 - plane containing the operands.
 --]]
local function vector_cross_product(a, b)
    local v = Vector({ a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x })
    return v
end

--[[ Return a vector multiplied by a scalar. --]]
local function vector_mul(a, s)
    local v = Vector({ a.x * s, a.y * s, a.z * s })
    return v
end

--[[ Return the vector norm (length). --]]
local function vector_norm(a)
    return sqrt(vector_dot_product(a, a))
end

--[[ Return a normalized version of the given vector. --]]
local function vector_normalize(a)
    local s = vector_norm(a)
    if s == 0 then
        return a
    end
    return vector_mul(a, 1 / s)
end

--[[ In-place add another vector to a vector. --]]
local function vector_iadd(a, b)
    a.x = a.x + b.x
    a.y = a.y + b.y
    a.z = a.z + b.z
end

--[[ Rotate the camera around the given axis. --]]
local function camera_rotate_around_axis(c, axis, radians)
    local t = allegro5.ALLEGRO_TRANSFORM()
    allegro5.al_identity_transform(t)
    allegro5.al_rotate_transform_3d(t, axis.x, axis.y, axis.z, radians)
    c.yaxis.x, c.yaxis.y, c.yaxis.z = allegro5.al_transform_coordinates_3d(t, c.yaxis.x, c.yaxis.y, c.yaxis.z)
    c.zaxis.x, c.zaxis.y, c.zaxis.z = allegro5.al_transform_coordinates_3d(t, c.zaxis.x, c.zaxis.y, c.zaxis.z)

    --[[ Make sure the axes remain orthogonal to each other. --]]
    c.zaxis = vector_normalize(c.zaxis)
    c.xaxis = vector_cross_product(c.yaxis, c.zaxis)
    c.xaxis = vector_normalize(c.xaxis)
    c.yaxis = vector_cross_product(c.zaxis, c.xaxis)
end

--[[ Move the camera along its x axis and z axis (which corresponds to
 - right and backwards directions).
 --]]
local function camera_move_along_direction(camera, right, forward)
    vector_iadd(camera.position, vector_mul(camera.xaxis, right))
    vector_iadd(camera.position, vector_mul(camera.zaxis, -forward))
end

--[[ Get a vector with y = 0 looking in the opposite direction as the camera z
 - axis. If looking straight up or down returns a 0 vector instead.
 --]]
local function get_ground_forward_vector(camera)
    local move = vector_mul(camera.zaxis, -1)
    move.y = 0
    return vector_normalize(move)
end

--[[ Get a vector with y = 0 looking in the same direction as the camera x axis.
 - If looking straight up or down returns a 0 vector instead.
 --]]
local function get_ground_right_vector(camera)
    local move = Vector({ camera.xaxis.x, camera.xaxis.y, camera.xaxis.z })
    move.y = 0
    return vector_normalize(move)
end

--[[ Like camera_move_along_direction but moves the camera along the ground plane
 - only.
 --]]
local function camera_move_along_ground(camera, right, forward)
    local f = get_ground_forward_vector(camera)
    local r = get_ground_right_vector(camera)
    camera.position.x = camera.position.x + f.x * forward + r.x * right
    camera.position.z = camera.position.z + f.z * forward + r.z * right
end

--[[ Calculate the pitch of the camera. This is the angle between the z axis
 - vector and our direction vector on the y = 0 plane.
 --]]
local function get_pitch(c)
    local f = get_ground_forward_vector(c)
    return asin(vector_dot_product(f, c.yaxis))
end

--[[ Calculate the yaw of the camera. This is basically the compass direction.
 --]]
local function get_yaw(c)
    return atan2(c.zaxis.x, c.zaxis.z)
end

--[[ Calculate the roll of the camera. This is the angle between the x axis
 - vector and its project on the y = 0 plane.
 --]]
local function get_roll(c)
    local r = get_ground_right_vector(c)
    return asin(vector_dot_product(r, c.yaxis))
end

--[[ Set up a perspective transform. We make the screen span
 - 2 vertical units (-1 to +1) with square pixel aspect and the camera's
 - vertical field of view. Clip distance is always set to 1.
 --]]
local function setup_3d_projection()
    local projection = allegro5.ALLEGRO_TRANSFORM()
    local display = allegro5.al_get_current_display()
    local dw = allegro5.al_get_display_width(display)
    local dh = allegro5.al_get_display_height(display)
    local f = 0
    allegro5.al_identity_transform(projection)
    allegro5.al_translate_transform_3d(projection, 0, 0, -1)
    f = tan(ex.camera.vertical_field_of_view / 2)
    allegro5.al_perspective_transform(projection, -1 * dw / dh * f, f,
        1,
        f * dw / dh, -f, 1000)
    allegro5.al_use_projection_transform(projection)
end

--[[ Adds a new vertex to our scene. --]]
local function add_vertex(x, y, z, u, v, color)
    local i = ex.n
    ex.n = ex.n + 1
    if i >= ex.v_size then
        if ex.v_size == 0 then
            ex.v_size = 1
        else
            ex.v_size = ex.v_size * 2
        end
        ex.v = pointer_cast("ALLEGRO_VERTEX", realloc(ex.v, ex.v_size * sizeof(allegro5.ALLEGRO_VERTEX)))
    end
    ex.v[i].x = x
    ex.v[i].y = y
    ex.v[i].z = z
    ex.v[i].u = u
    ex.v[i].v = v
    ex.v[i].color = color
end

--[[ Adds two triangles (6 vertices) to the scene. --]]
local function add_quad(x, y, z, u, v, ux, uy, uz, uu, uv, vx, vy, vz, vu, vv, c1, c2)
    add_vertex(x, y, z, u, v, c1)
    add_vertex(x + ux, y + uy, z + uz, u + uu, v + uv, c1)
    add_vertex(x + vx, y + vy, z + vz, u + vu, v + vv, c2)
    add_vertex(x + vx, y + vy, z + vz, u + vu, v + vv, c2)
    add_vertex(x + ux, y + uy, z + uz, u + uu, v + uv, c1)
    add_vertex(x + ux + vx, y + uy + vy, z + uz + vz, u + uu + vu,
        v + uv + vv, c2)
end

--[[ Create a checkerboard made from colored quads. --]]
local function add_checkerboard()
    local c1 = allegro5.al_color_name("yellow")
    local c2 = allegro5.al_color_name("green")

    for y = 0, 20 - INDEX_BASE do
        for x = 0, 20 - INDEX_BASE do
            local px = x - 20 * 0.5
            local py = 0.2
            local pz = y - 20 * 0.5
            local c = c1
            if bit.band((x + y), 1) ~= 0 then
                c = c2
                py = py - 0.1
            end
            add_quad(px, py, pz, 0, 0,
                1, 0, 0, 0, 0,
                0, 0, 1, 0, 0,
                c, c)
        end
    end
end

--[[ Create a skybox. This is simply 5 quads with a fixed distance to the
 - camera.
 --]]
local function add_skybox()
    local p = ex.camera.position
    local c1 = allegro5.al_color_name("black")
    local c2 = allegro5.al_color_name("blue")
    local c3 = allegro5.al_color_name("white")

    local a, b = 0, 0
    if ex.skybox then
        a = allegro5.al_get_bitmap_width(ex.skybox) / 4.0
        b = allegro5.al_get_bitmap_height(ex.skybox) / 3.0
        c2 = c3; c1 = c2
    end

    --[[ Back skybox wall. --]]
    add_quad(p.x - 50, p.y - 50, p.z - 50, a * 4, b * 2,
        100, 0, 0, -a, 0,
        0, 100, 0, 0, -b,
        c1, c2)
    --[[ Front skybox wall. --]]
    add_quad(p.x - 50, p.y - 50, p.z + 50, a, b * 2,
        100, 0, 0, a, 0,
        0, 100, 0, 0, -b,
        c1, c2)
    --[[ Left skybox wall. --]]
    add_quad(p.x - 50, p.y - 50, p.z - 50, 0, b * 2,
        0, 0, 100, a, 0,
        0, 100, 0, 0, -b,
        c1, c2)
    --[[ Right skybox wall. --]]
    add_quad(p.x + 50, p.y - 50, p.z - 50, a * 3, b * 2,
        0, 0, 100, -a, 0,
        0, 100, 0, 0, -b,
        c1, c2)

    --[[ Top of skybox. --]]
    add_vertex(p.x - 50, p.y + 50, p.z - 50, a, 0, c2)
    add_vertex(p.x + 50, p.y + 50, p.z - 50, a * 2, 0, c2)
    add_vertex(p.x, p.y + 50, p.z, a * 1.5, b * 0.5, c3)

    add_vertex(p.x + 50, p.y + 50, p.z - 50, a * 2, 0, c2)
    add_vertex(p.x + 50, p.y + 50, p.z + 50, a * 2, b, c2)
    add_vertex(p.x, p.y + 50, p.z, a * 1.5, b * 0.5, c3)

    add_vertex(p.x + 50, p.y + 50, p.z + 50, a * 2, b, c2)
    add_vertex(p.x - 50, p.y + 50, p.z + 50, a, b, c2)
    add_vertex(p.x, p.y + 50, p.z, a * 1.5, b * 0.5, c3)

    add_vertex(p.x - 50, p.y + 50, p.z + 50, a, b, c2)
    add_vertex(p.x - 50, p.y + 50, p.z - 50, a, 0, c2)
    add_vertex(p.x, p.y + 50, p.z, a * 1.5, b * 0.5, c3)
end

local function draw_scene()
    local c = ex.camera
    --[[ We save Allegro's projection so we can restore it for drawing text. --]]
    local projection = copy(allegro5.ALLEGRO_TRANSFORM, allegro5.al_get_current_projection_transform())
    local t = allegro5.ALLEGRO_TRANSFORM()
    local back = allegro5.al_color_name("black")
    local front = allegro5.al_color_name("white")
    local th = 0
    local pitch, yaw, roll = 0, 0, 0

    setup_3d_projection()
    allegro5.al_clear_to_color(back)

    --[[ We use a depth buffer. --]]
    allegro5.al_set_render_state(allegro5.ALLEGRO_DEPTH_TEST, 1)
    allegro5.al_clear_depth_buffer(1)

    --[[ Recreate the entire scene geometry - this is only a very small example
    - so this is fine.
    --]]
    ex.n = 0
    add_checkerboard()
    add_skybox()

    --[[ Construct a transform corresponding to our camera. This is an inverse
    - translation by the camera position, followed by an inverse rotation
    - from the camera orientation.
    --]]
    allegro5.al_build_camera_transform(t,
        ex.camera.position.x, ex.camera.position.y, ex.camera.position.z,
        ex.camera.position.x - ex.camera.zaxis.x,
        ex.camera.position.y - ex.camera.zaxis.y,
        ex.camera.position.z - ex.camera.zaxis.z,
        ex.camera.yaxis.x, ex.camera.yaxis.y, ex.camera.yaxis.z)
    allegro5.al_use_transform(t)
    allegro5.al_draw_prim(ex.v, nil, ex.skybox, 0, ex.n, allegro5.ALLEGRO_PRIM_TRIANGLE_LIST)

    --[[ Restore projection. --]]
    allegro5.al_identity_transform(t)
    allegro5.al_use_transform(t)
    allegro5.al_use_projection_transform(projection)
    allegro5.al_set_render_state(allegro5.ALLEGRO_DEPTH_TEST, 0)

    --[[ Draw some text. --]]
    th = allegro5.al_get_font_line_height(ex.font)
    allegro5.al_draw_textf(ex.font, front, 0, th * 0, 0,
        "look: %+3.1f/%+3.1f/%+3.1f (change with left mouse button and drag)",
        -c.zaxis.x, -c.zaxis.y, -c.zaxis.z)
    pitch = get_pitch(c) * 180 / pi
    yaw = get_yaw(c) * 180 / pi
    roll = get_roll(c) * 180 / pi
    allegro5.al_draw_textf(ex.font, front, 0, th * 1, 0,
        "pitch: %+4.0f yaw: %+4.0f roll: %+4.0f", pitch, yaw, roll)
    allegro5.al_draw_textf(ex.font, front, 0, th * 2, 0,
        "vertical field of view: %3.1f (change with Z/X)",
        c.vertical_field_of_view * 180 / pi)
    allegro5.al_draw_textf(ex.font, front, 0, th * 3, 0, "move with WASD or cursor")
    allegro5.al_draw_textf(ex.font, front, 0, th * 4, 0, "control style: %s (space to change)",
        ex.controls_names[ex.controls + INDEX_BASE])
end

local function setup_scene()
    ex.camera.xaxis.x = 1
    ex.camera.yaxis.y = 1
    ex.camera.zaxis.z = 1
    ex.camera.position.y = 2
    ex.camera.vertical_field_of_view = 60 * pi / 180

    ex.mouse_look_speed = 0.03
    ex.movement_speed = 0.05

    ex.controls_names[0 + INDEX_BASE] = "FPS"
    ex.controls_names[1 + INDEX_BASE] = "airplane"
    ex.controls_names[2 + INDEX_BASE] = "spaceship"

    ex.font = allegro5.al_create_builtin_font()
end

local function handle_input()
    local x, y = 0, 0
    local xy = 0
    if ex.key[allegro5.ALLEGRO_KEY_A + INDEX_BASE] or ex.key[allegro5.ALLEGRO_KEY_LEFT + INDEX_BASE] then
        x = -1
    end
    if ex.key[allegro5.ALLEGRO_KEY_S + INDEX_BASE] or ex.key[allegro5.ALLEGRO_KEY_DOWN + INDEX_BASE] then
        y = -1
    end
    if ex.key[allegro5.ALLEGRO_KEY_D + INDEX_BASE] or ex.key[allegro5.ALLEGRO_KEY_RIGHT + INDEX_BASE] then
        x = 1
    end
    if ex.key[allegro5.ALLEGRO_KEY_W + INDEX_BASE] or ex.key[allegro5.ALLEGRO_KEY_UP + INDEX_BASE] then
        y = 1
    end

    --[[ Change field of view with Z/X. --]]
    if ex.key[allegro5.ALLEGRO_KEY_Z + INDEX_BASE] then
        local m = 20 * pi / 180
        ex.camera.vertical_field_of_view = ex.camera.vertical_field_of_view - 0.01
        if ex.camera.vertical_field_of_view < m then
            ex.camera.vertical_field_of_view = m
        end
    end
    if ex.key[allegro5.ALLEGRO_KEY_X + INDEX_BASE] then
        local m = 120 * pi / 180
        ex.camera.vertical_field_of_view = ex.camera.vertical_field_of_view + 0.01
        if ex.camera.vertical_field_of_view > m then
            ex.camera.vertical_field_of_view = m
        end
    end

    --[[ In FPS style, always move the camera to height 2. --]]
    if ex.controls == 0 then
        if ex.camera.position.y > 2 then
            ex.camera.position.y = ex.camera.position.y - 0.1
        end
        if ex.camera.position.y < 2 then
            ex.camera.position.y = 2
        end
    end

    --[[ Set the roll (leaning) angle to 0 if not in airplane style. --]]
    if ex.controls == 0 or ex.controls == 2 then
        local roll = get_roll(ex.camera)
        camera_rotate_around_axis(ex.camera, ex.camera.zaxis, roll / 60)
    end

    --[[ Move the camera, either freely or along the ground. --]]
    xy = sqrt(x * x + y * y)
    if xy > 0 then
        x = x / xy
        y = y / xy
        if ex.controls == 0 then
            camera_move_along_ground(ex.camera, ex.movement_speed * x,
                ex.movement_speed * y)
        end
        if ex.controls == 1 or ex.controls == 2 then
            camera_move_along_direction(ex.camera, ex.movement_speed * x,
                ex.movement_speed * y)
        end
    end

    --[[ Rotate the camera, either freely or around world up only. --]]
    if ex.button[1 + INDEX_BASE] then
        if ex.controls == 0 or ex.controls == 2 then
            local up = Vector({ 0, 1, 0 })
            camera_rotate_around_axis(ex.camera, ex.camera.xaxis,
                -ex.mouse_look_speed * ex.mouse_dy)
            camera_rotate_around_axis(ex.camera, up,
                -ex.mouse_look_speed * ex.mouse_dx)
        end
        if ex.controls == 1 then
            camera_rotate_around_axis(ex.camera, ex.camera.xaxis,
                -ex.mouse_look_speed * ex.mouse_dy)
            camera_rotate_around_axis(ex.camera, ex.camera.zaxis,
                -ex.mouse_look_speed * ex.mouse_dx)
        end
    end
end

local function main(argv)
    local argc = #argv

    local redraw = false
    local halt_drawing = false
    local skybox_name = nil

    if argc >= 1 then
        skybox_name = argv[1]
    end

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    allegro5.al_init_font_addon()
    allegro5.al_init_primitives_addon()
    init_platform_specific()
    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()

    allegro5.al_set_config_value(allegro5.al_get_system_config(), "osx", "allow_live_resize", "false")
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLE_BUFFERS, 1, allegro5.ALLEGRO_SUGGEST)
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLES, 8, allegro5.ALLEGRO_SUGGEST)
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_DEPTH_SIZE, 16, allegro5.ALLEGRO_SUGGEST)
    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_RESIZABLE)
    local display = allegro5.al_create_display(640, 360)
    if not display then
        abort_example("Error creating display\n")
    end

    if skybox_name then
        allegro5.al_init_image_addon()
        ex.skybox = allegro5.al_load_bitmap(skybox_name)
        if ex.skybox then
            log_printf("Loaded skybox %s: %d x %d\n", skybox_name,
                allegro5.al_get_bitmap_width(ex.skybox),
                allegro5.al_get_bitmap_height(ex.skybox))
        else
            log_printf("Failed loading skybox %s\n", skybox_name)
        end
    end

    local timer = allegro5.al_create_timer(1.0 / 60)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    setup_scene()

    allegro5.al_start_timer(timer)
    while true do
        local event = allegro5.ALLEGRO_EVENT()

        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(display)
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
                ex.controls = ex.controls + 1
                ex.controls = ex.controls % 3
            end
            ex.key[event.keyboard.keycode + INDEX_BASE] = true
            ex.keystate[event.keyboard.keycode + INDEX_BASE] = true
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_UP then
            --[[ In case a key gets pressed and immediately released, we will still
          - have set ex.key so it is not lost.
          --]]
            ex.keystate[event.keyboard.keycode + INDEX_BASE] = false
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            handle_input()
            redraw = true

            --[[ Reset keyboard state for keys not held down anymore. --]]
            for i = 0, allegro5.ALLEGRO_KEY_MAX - INDEX_BASE do
                if not ex.keystate[i + INDEX_BASE] then
                    ex.key[i + INDEX_BASE] = false
                end
            end
            ex.mouse_dx = 0
            ex.mouse_dy = 0
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
            ex.button[event.mouse.button + INDEX_BASE] = true
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_UP then
            ex.button[event.mouse.button + INDEX_BASE] = false
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_HALT_DRAWING then
            halt_drawing = true
            allegro5.al_acknowledge_drawing_halt(display)
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESUME_DRAWING then
            halt_drawing = false
            allegro5.al_acknowledge_drawing_resume(display)
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_AXES then
            ex.mouse_dx = ex.mouse_dx + event.mouse.dx
            ex.mouse_dy = ex.mouse_dy + event.mouse.dy
        end

        if not halt_drawing and redraw and allegro5.al_is_event_queue_empty(queue) then
            draw_scene()

            allegro5.al_flip_display()
            redraw = false
        end
    end

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
