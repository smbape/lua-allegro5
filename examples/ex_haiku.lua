#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_haiku.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local open_log = common.open_log
local init_platform_specific = common.init_platform_specific
local close_log = common.close_log
local rand = common.rand
local RAND_MAX = common.RAND_MAX

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 -    Haiku - A Musical Instrument, by Mark Oates.
 -
 -    Allegro example version by Peter Wang.
 -
 -    It demonstrates use of the audio functions, and other things besides.
 --]]

--[[ This version leaves out some things from Mark's original version:
 - the nice title sequence, text labels and mouse cursors.
 --]]

local PI               = allegro5.ALLEGRO_PI
local TWOPI            = allegro5.ALLEGRO_PI * 2.0

local TYPE_EARTH       = 0
local TYPE_WIND        = 1
local TYPE_WATER       = 2
local TYPE_FIRE        = 3
local NUM_TYPES        = 4
local TYPE_NONE        = NUM_TYPES

local IMG_EARTH        = TYPE_EARTH
local IMG_WIND         = TYPE_WIND
local IMG_WATER        = TYPE_WATER
local IMG_FIRE         = TYPE_FIRE
local IMG_BLACK        = 4
local IMG_DROPSHADOW   = 5
local IMG_GLOW         = 6
local IMG_GLOW_OVERLAY = 7
local IMG_AIR_EFFECT   = 8
local IMG_WATER_DROPS  = 9
local IMG_FLAME        = 10
local IMG_MAIN_FLAME   = 11
local IMG_MAX          = 12

local Interp           = {
    INTERP_LINEAR = 0,
    INTERP_FAST = 1,
    INTERP_DOUBLE_FAST = 2,
    INTERP_SLOW = 3,
    INTERP_DOUBLE_SLOW = 4,
    INTERP_SLOW_IN_OUT = 5,
    INTERP_BOUNCE = 6
}

local MAX_ANIMS        = 10
local global_id        = 0

local function Anim(initializer_list)
    if initializer_list == nil then
        initializer_list = {
            --[[ lval =  --]] { 0 },
            --[[ start_val =  --]] 0,
            --[[ end_val =  --]] 0,
            --[[ func =  --]] Interp.INTERP_LINEAR,
            --[[ start_time =  --]] 0,
            --[[ end_time =  --]] 0,
        }
    end

    global_id = global_id + 1

    return {
        id = global_id,
        lval = initializer_list[1],
        start_val = initializer_list[2],
        end_val = initializer_list[3],
        func = initializer_list[4],
        start_time = initializer_list[5],
        end_time = initializer_list[6],
    }
end

local function Sprite(initializer_list)
    if initializer_list == nil then
        initializer_list = {
            --[[ image = --]] 0,
            --[[ x = --]] { 0 }, --[[ scale_x = --]] { 0 }, --[[ align_x = --]] 0,
            --[[ y = --]] { 0 }, --[[ scale_y = --]] { 0 }, --[[ align_y = --]] 0,
            --[[ angle = --]] { 0 },
            --[[ r = --]] { 0 }, --[[ g = --]] { 0 }, --[[ b = --]] { 0 },
            --[[ opacity = --]] { 0 },
            --[[ anims = --]] (function()
            local anims = {}
            for i = 1, MAX_ANIMS do
                anims[i] = Anim()
            end
            return anims
        end)()
        }
    end

    return {
        image = initializer_list[1], --[[ IMG_ --]]
        x = initializer_list[2],
        scale_x = initializer_list[3],
        align_x = initializer_list[4],
        y = initializer_list[5],
        scale_y = initializer_list[6],
        align_y = initializer_list[7],
        angle = initializer_list[8],
        r = initializer_list[9],
        g = initializer_list[10],
        b = initializer_list[11],
        opacity = initializer_list[12],
        anims = initializer_list[13]
    }
end

local function Token(initializer_list)
    if initializer_list == nil then
        initializer_list = {
            --[[ type = --]] 0,
            --[[ x = --]] 0,
            --[[ y = --]] 0,
            --[[ pitch = --]] 0,
            --[[ bot = --]] Sprite(),
            --[[ top = --]] Sprite(),
        }
    end

    return {
        type = initializer_list[1], --[[ TYPE_ --]]
        x = initializer_list[2],
        y = initializer_list[3],
        pitch = initializer_list[4], --[[ [0, NUM_PITCH) --]]
        bot = initializer_list[5],
        top = initializer_list[6],
    }
end

local function Flair(initializer_list)
    if initializer_list == nil then
        initializer_list = {
            --[[ next = --]] nil,
            --[[ end_time = --]] 0,
            --[[ sprite = --]] Sprite(),
        }
    end

    return {
        next = initializer_list[1],
        end_time = initializer_list[2],
        sprite = initializer_list[3],
    }
end

--[[**************************************************************************--]]
--[[ Globals                                                                  --]]
--[[**************************************************************************--]]

local NUM_PITCH              = 8
local TOKENS_X               = 16
local TOKENS_Y               = NUM_PITCH
local NUM_TOKENS             = TOKENS_X * TOKENS_Y

local display
local refresh_timer
local playback_timer

local images                 = {}
local element_samples        = (function()
    local element_samples = {}
    for i = 1, NUM_TYPES do
        element_samples[i] = {}
    end
    return element_samples
end)()
local select_sample

local tokens                 = (function()
    local tokens = {}
    for i = 1, NUM_TOKENS do
        tokens[i] = Token()
    end
    return tokens
end)()
local buttons                = (function()
    local buttons = {}
    for i = 1, NUM_TYPES do
        buttons[i] = Token()
    end
    return buttons
end)()
local glow                   = Sprite()
local glow_overlay           = Sprite()
local glow_color             = {}
local flairs                 = nil
local hover_token            = nil
local selected_button        = nil
local playback_column        = 0

local screen_w               = 1024
local screen_h               = 600
local game_board_x           = 100.0
local token_size             = 64
local token_scale            = 0.8
local button_size            = 64
local button_unsel_scale     = 0.8
local button_sel_scale       = 1.1
local dropshadow_unsel_scale = 0.6
local dropshadow_sel_scale   = 0.9
local refresh_rate           = 60.0
local playback_period        = 2.7333

local HAIKU_DATA             = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/haiku/"

--[[**************************************************************************--]]
--[[ Init                                                                     --]]
--[[**************************************************************************--]]

local function load_images()
    images[IMG_EARTH + INDEX_BASE]        = allegro5.al_load_bitmap(HAIKU_DATA .. "earth4.png")
    images[IMG_WIND + INDEX_BASE]         = allegro5.al_load_bitmap(HAIKU_DATA .. "wind3.png")
    images[IMG_WATER + INDEX_BASE]        = allegro5.al_load_bitmap(HAIKU_DATA .. "water.png")
    images[IMG_FIRE + INDEX_BASE]         = allegro5.al_load_bitmap(HAIKU_DATA .. "fire.png")
    images[IMG_BLACK + INDEX_BASE]        = allegro5.al_load_bitmap(HAIKU_DATA .. "black_bead_opaque_A.png")
    images[IMG_DROPSHADOW + INDEX_BASE]   = allegro5.al_load_bitmap(HAIKU_DATA .. "dropshadow.png")
    images[IMG_AIR_EFFECT + INDEX_BASE]   = allegro5.al_load_bitmap(HAIKU_DATA .. "air_effect.png")
    images[IMG_WATER_DROPS + INDEX_BASE]  = allegro5.al_load_bitmap(HAIKU_DATA .. "water_droplets.png")
    images[IMG_FLAME + INDEX_BASE]        = allegro5.al_load_bitmap(HAIKU_DATA .. "flame2.png")
    images[IMG_MAIN_FLAME + INDEX_BASE]   = allegro5.al_load_bitmap(HAIKU_DATA .. "main_flame2.png")
    images[IMG_GLOW + INDEX_BASE]         = allegro5.al_load_bitmap(HAIKU_DATA .. "healthy_glow.png")
    images[IMG_GLOW_OVERLAY + INDEX_BASE] = allegro5.al_load_bitmap(HAIKU_DATA .. "overlay_pretty.png")

    for i = 0, IMG_MAX - INDEX_BASE do
        if images[i + INDEX_BASE] == nil then
            abort_example("Error loading image.\n")
        end
    end
end

local function load_samples()
    local base = { "earth", "air", "water", "fire" }

    for t = 0, NUM_TYPES - INDEX_BASE do
        for p = 0, NUM_PITCH - INDEX_BASE do
            local name = string.format(HAIKU_DATA .. "%s_%d.ogg", base[t + INDEX_BASE], p)
            element_samples[t + INDEX_BASE][p + INDEX_BASE] = allegro5.al_load_sample(name)
            if not element_samples[t + INDEX_BASE][p + INDEX_BASE] then
                abort_example("Error loading %s.\n", name)
            end
        end
    end

    select_sample = allegro5.al_load_sample(HAIKU_DATA .. "select.ogg")
    if not select_sample then
        abort_example("Error loading select.ogg.\n")
    end
end

local function init_sprite(spr, image, x, y, scale, opacity)
    spr.image = image
    spr.x[1] = x
    spr.y[1] = y
    spr.scale_y[1] = scale; spr.scale_x[1] = spr.scale_y[1]
    spr.align_y = 0.5; spr.align_x = spr.align_y
    spr.angle[1] = 0.0
    spr.b[1] = 1.0; spr.g[1] = spr.b[1]; spr.r[1] = spr.g[1]
    spr.opacity[1] = opacity
    for i = 1, MAX_ANIMS do
        spr.anims[i].lval = nil
    end
end

local function init_tokens()
    local token_w = token_size * token_scale
    local token_x = game_board_x + token_w / 2.0
    local token_y = 80

    for i = 0, NUM_TOKENS - INDEX_BASE do
        local tx = i % TOKENS_X
        local ty = math.floor(i / TOKENS_X)
        local px = token_x + tx * token_w
        local py = token_y + ty * token_w

        tokens[i + INDEX_BASE].type = TYPE_NONE
        tokens[i + INDEX_BASE].x = px
        tokens[i + INDEX_BASE].y = py
        tokens[i + INDEX_BASE].pitch = NUM_PITCH - 1 - ty
        assert(tokens[i + INDEX_BASE].pitch >= 0 and tokens[i + INDEX_BASE].pitch < NUM_PITCH)
        init_sprite(tokens[i + INDEX_BASE].bot, IMG_BLACK, px, py, token_scale, 0.4)
        init_sprite(tokens[i + INDEX_BASE].top, IMG_BLACK, px, py, token_scale, 0.0)
    end
end

local function init_buttons()
    local dist = { -1.5, -0.5, 0.5, 1.5 }

    for i = 0, NUM_TYPES - INDEX_BASE do
        local x = screen_w / 2 + 150 * dist[i + INDEX_BASE]
        local y = screen_h - 80

        buttons[i + INDEX_BASE].type = i
        buttons[i + INDEX_BASE].x = x
        buttons[i + INDEX_BASE].y = y
        init_sprite(buttons[i + INDEX_BASE].bot, IMG_DROPSHADOW, x, y,
            dropshadow_unsel_scale, 0.4)
        buttons[i + INDEX_BASE].bot.align_y = 0.0
        init_sprite(buttons[i + INDEX_BASE].top, i, x, y, button_unsel_scale, 1.0)
    end
end

local function init_glow()
    init_sprite(glow, IMG_GLOW, screen_w / 2, screen_h, 1.0, 1.0)
    glow.align_y = 1.0
    glow.b[1] = 0.0; glow.g[1] = glow.b[1]; glow.r[1] = glow.g[1]

    init_sprite(glow_overlay, IMG_GLOW_OVERLAY, 0.0, 0.0, 1.0, 1.0)
    glow_overlay.align_x                = 0.0
    glow_overlay.align_y                = 0.0
    glow_overlay.b[1]                   = 0.0
    glow_overlay.g[1]                   = glow_overlay.b[1]
    glow_overlay.r[1]                   = glow_overlay.g[1]

    glow_color[TYPE_EARTH + INDEX_BASE] = allegro5.al_map_rgb(0x6b, 0x8e, 0x23); --[[ olivedrab --]]
    glow_color[TYPE_WIND + INDEX_BASE]  = allegro5.al_map_rgb(0xad, 0xd8, 0xe6); --[[ lightblue --]]
    glow_color[TYPE_WATER + INDEX_BASE] = allegro5.al_map_rgb(0x41, 0x69, 0xe1); --[[ royalblue --]]
    glow_color[TYPE_FIRE + INDEX_BASE]  = allegro5.al_map_rgb(0xff, 0x00, 0x00); --[[ red --]]
end

--[[**************************************************************************--]]
--[[ Flairs                                                                   --]]
--[[**************************************************************************--]]

local function make_flair(image, x, y, end_time)
    local fl = Flair()
    init_sprite(fl.sprite, image, x, y, 1.0, 1.0)
    fl.end_time = end_time
    fl.next = flairs
    flairs = fl
    return fl.sprite
end

local function free_old_flairs(now)
    local prev, fl, _next
    fl = flairs
    while fl do
        _next = fl.next
        if fl.end_time > now then
            prev = fl
        else
            if prev then
                prev.next = _next
            else
                flairs = _next
            end
            -- free(fl)
        end
        fl = _next
    end
end

local function free_all_flairs()
    local _next

    while flairs do
        _next = flairs.next
        -- free(flairs)
        flairs = _next
    end
end

--[[**************************************************************************--]]
--[[ Animations                                                               --]]
--[[**************************************************************************--]]

local get_next_anim = (function()
    local dummy_anim = Anim()

    local function get_next_anim(spr)
        for i = 1, MAX_ANIMS do
            if spr.anims[i].lval == nil then
                return spr.anims[i]
            end
        end

        assert(false)
        return dummy_anim
    end

    return get_next_anim
end)()

local function fix_conflicting_anims(grp, lval, start_time, start_val)
    for i = 1, MAX_ANIMS do
        local anim = grp.anims[i]

        if anim.lval == lval then
            --[[ If an old animation would overlap with the new one, truncate it
           - and make it converge to the new animation's starting value.
           --]]
            if anim.end_time > start_time then
                anim.end_time = start_time
                anim.end_val = start_val
            end

            --[[ Cancel any old animations which are scheduled to start after the
           - new one, or which have been reduced to nothing.
           --]]
            if anim.start_time >= start_time or
                anim.start_time >= anim.end_time
            then
                grp.anims[i].lval = nil
            end
        end
    end
end

local function anim_full(spr, lval, start_val, end_val, func, delay, duration)
    local start_time = allegro5.al_get_time() + delay
    fix_conflicting_anims(spr, lval, start_time, start_val)

    local anim = get_next_anim(spr)
    anim.lval = lval
    anim.start_val = start_val
    anim.end_val = end_val
    anim.func = func
    anim.start_time = start_time
    anim.end_time = start_time + duration
end

local function anim(spr, lval, start_val, end_val, func, duration)
    anim_full(spr, lval, start_val, end_val, func, 0.0, duration)
end

local function anim_to(spr, lval, end_val, func, duration)
    anim_full(spr, lval, lval[1], end_val, func, 0.0, duration)
end

local function anim_delta(spr, lval, delta, func, duration)
    anim_full(spr, lval, lval[1], lval[1] + delta, func, 0.0, duration)
end

local function anim_tint(spr, color, func, duration)
    local r, g, b = allegro5.al_unmap_rgb_f(color)
    anim_to(spr, spr.r, r, func, duration)
    anim_to(spr, spr.g, g, func, duration)
    anim_to(spr, spr.b, b, func, duration)
end

local function interpolate(func, t)
    if func == Interp.INTERP_LINEAR then
        return t
    elseif func == Interp.INTERP_FAST then
        return -t * (t - 2)
    elseif func == Interp.INTERP_DOUBLE_FAST then
        t = t - 1
        return t * t * t + 1
    elseif func == Interp.INTERP_SLOW then
        return t * t
    elseif func == Interp.INTERP_DOUBLE_SLOW then
        return t * t * t
    elseif func == Interp.INTERP_SLOW_IN_OUT then
        -- Quadratic easing in/out - acceleration until halfway, then deceleration
        local b = 0
        local c = 1
        local d = 1
        t = t / (d / 2)
        if t < 1 then
            return c / 2 * t * t + b
        else
            t = t - 1
            return -c / 2 * (t * (t - 2) - 1) + b
        end
    elseif func == Interp.INTERP_BOUNCE then
        -- BOUNCE EASING: exponentially decaying parabolic bounce
        -- t: current time, b: beginning value, c: change in position, d: duration
        -- bounce easing out
        if t < (1 / 2.75) then
            return (7.5625 * t * t)
        end
        if t < (2 / 2.75) then
            t = t - (1.5 / 2.75)
            return (7.5625 * t * t + 0.75)
        end
        if t < (2.5 / 2.75) then
            t = t - (2.25 / 2.75)
            return (7.5625 * t * t + 0.9375)
        end
        t = t - (2.625 / 2.75)
        return (7.5625 * t * t + 0.984375)
    else
        assert(false)
        return 0.0
    end
end

local function update_anim(anim, now)
    if not anim.lval then
        return
    end

    if now < anim.start_time then
        return
    end

    local dt = now - anim.start_time
    local t = dt / (anim.end_time - anim.start_time)

    if t >= 1.0 then
        --[[ animation has run to completion --]]
        anim.lval[1] = anim.end_val
        anim.lval = nil
        return
    end

    local range = anim.end_val - anim.start_val
    anim.lval[1] = anim.start_val + interpolate(anim.func, t) * range
end

local function update_sprite_anims(spr, now)
    for i = 1, MAX_ANIMS do
        update_anim(spr.anims[i], now)
    end
end

local function update_token_anims(token, now)
    update_sprite_anims(token.bot, now)
    update_sprite_anims(token.top, now)
end

local function update_anims(now)
    for i = 1, NUM_TOKENS do
        update_token_anims(tokens[i], now)
    end

    for i = 1, NUM_TYPES do
        update_token_anims(buttons[i], now)
    end

    update_sprite_anims(glow, now)
    update_sprite_anims(glow_overlay, now)

    local fl = flairs
    while fl do
        update_sprite_anims(fl.sprite, now)
        fl = fl.next
    end
end

--[[**************************************************************************--]]
--[[ Drawing                                                                  --]]
--[[**************************************************************************--]]

local function draw_sprite(spr)
    local bmp = images[spr.image + INDEX_BASE]
    local cx = spr.align_x * allegro5.al_get_bitmap_width(bmp)
    local cy = spr.align_y * allegro5.al_get_bitmap_height(bmp)
    local tint = allegro5.al_map_rgba_f(spr.r[1], spr.g[1], spr.b[1], spr.opacity[1])

    allegro5.al_draw_tinted_scaled_rotated_bitmap(bmp, tint, cx, cy,
        spr.x[1], spr.y[1], spr.scale_x[1], spr.scale_y[1], spr.angle[1], 0)
end

local function draw_token(token)
    draw_sprite(token.bot)
    draw_sprite(token.top)
end

local function draw_screen()
    allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_ONE)

    draw_sprite(glow)
    draw_sprite(glow_overlay)

    for i = 1, NUM_TOKENS do
        draw_token(tokens[i])
    end

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)

    for i = 1, NUM_TYPES do
        draw_token(buttons[i])
    end

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_ONE)

    local fl = flairs
    while fl do
        draw_sprite(fl.sprite)
        fl = fl.next
    end

    allegro5.al_flip_display()
end

--[[**************************************************************************--]]
--[[ Playback                                                                 --]]
--[[**************************************************************************--]]

local function spawn_wind_effects(x, y)
    local now = allegro5.al_get_time()
    local spr

    spr = make_flair(IMG_AIR_EFFECT, x, y, now + 1.0)
    anim(spr, spr.scale_x, 0.9, 1.3, Interp.INTERP_FAST, 1.0)
    anim(spr, spr.scale_y, 0.9, 1.3, Interp.INTERP_FAST, 1.0)
    anim(spr, spr.opacity, 1.0, 0.0, Interp.INTERP_FAST, 1.0)

    spr = make_flair(IMG_AIR_EFFECT, x, y, now + 1.2)
    anim(spr, spr.opacity, 1.0, 0.0, Interp.INTERP_LINEAR, 1.2)
    anim(spr, spr.scale_x, 1.1, 1.5, Interp.INTERP_FAST, 1.2)
    anim(spr, spr.scale_y, 1.1, 0.5, Interp.INTERP_FAST, 1.2)
    anim_delta(spr, spr.x, 10.0, Interp.INTERP_FAST, 1.2)
end

local function spawn_fire_effects(x, y)
    local now = allegro5.al_get_time()
    local spr

    spr = make_flair(IMG_MAIN_FLAME, x, y, now + 0.8)
    spr.align_y = 0.75
    anim_full(spr, spr.scale_x, 0.2, 1.3, Interp.INTERP_BOUNCE, 0.0, 0.4)
    anim_full(spr, spr.scale_y, 0.2, 1.3, Interp.INTERP_BOUNCE, 0.0, 0.4)
    anim_full(spr, spr.scale_x, 1.3, 1.4, Interp.INTERP_BOUNCE, 0.4, 0.5)
    anim_full(spr, spr.scale_y, 1.3, 1.4, Interp.INTERP_BOUNCE, 0.4, 0.5)
    anim_full(spr, spr.opacity, 1.0, 0.0, Interp.INTERP_FAST, 0.3, 0.5)

    for i = 0, 3 - INDEX_BASE do
        spr = make_flair(IMG_FLAME, x, y, now + 0.7)
        spr.align_x = 1.3
        spr.angle[1] = TWOPI / 3 * i

        anim_delta(spr, spr.angle, -PI, Interp.INTERP_DOUBLE_FAST, 0.7)
        anim(spr, spr.opacity, 1.0, 0.0, Interp.INTERP_SLOW, 0.7)
        anim(spr, spr.scale_x, 0.2, 1.0, Interp.INTERP_FAST, 0.7)
        anim(spr, spr.scale_y, 0.2, 1.0, Interp.INTERP_FAST, 0.7)
    end
end

local function random_sign()
    return (function() if (rand() % 2) then return -1.0 else return 1.0 end end)()
end

local function random_float(min, max)
    return (rand() / RAND_MAX) * (max - min) + min
end

local function spawn_water_effects(x, y)
    local now = allegro5.al_get_time()
    local max_duration = 1.0

    local function RAND(a, b)
        return random_float((a), (b))
    end

    local function MRAND(a, b)
        return random_float((a), (b)) * max_duration
    end

    local function SIGN()
        return random_sign()
    end

    local spr = make_flair(IMG_WATER, x, y, now + max_duration)
    anim(spr, spr.scale_x, 1.0, 2.0, Interp.INTERP_FAST, 0.5)
    anim(spr, spr.scale_y, 1.0, 2.0, Interp.INTERP_FAST, 0.5)
    anim(spr, spr.opacity, 0.5, 0.0, Interp.INTERP_FAST, 0.5)

    for i = 0, 9 - INDEX_BASE do
        spr = make_flair(IMG_WATER_DROPS, x, y, now + max_duration)
        spr.scale_x[1] = RAND(0.3, 1.2) * SIGN()
        spr.scale_y[1] = RAND(0.3, 1.2) * SIGN()
        spr.angle[1] = RAND(0.0, TWOPI)
        spr.r[1] = RAND(0.0, 0.6)
        spr.g[1] = RAND(0.4, 0.6)
        spr.b[1] = 1.0

        if i == 0 then
            anim_to(spr, spr.opacity, 0.0, Interp.INTERP_LINEAR, max_duration)
        else
            anim_to(spr, spr.opacity, 0.0, Interp.INTERP_DOUBLE_SLOW, MRAND(0.7, 1.0))
        end
        anim_to(spr, spr.scale_x, RAND(0.8, 3.0), Interp.INTERP_FAST, MRAND(0.7, 1.0))
        anim_to(spr, spr.scale_y, RAND(0.8, 3.0), Interp.INTERP_FAST, MRAND(0.7, 1.0))
        anim_delta(spr, spr.x, MRAND(0, 20.0) * SIGN(), Interp.INTERP_FAST, MRAND(0.7, 1.0))
        anim_delta(spr, spr.y, MRAND(0, 20.0) * SIGN(), Interp.INTERP_FAST, MRAND(0.7, 1.0))
    end
end

local function play_element(_type, pitch, vol, pan)
    allegro5.al_play_sample(element_samples[_type + INDEX_BASE][pitch + INDEX_BASE], vol, pan, 1.0,
        allegro5.ALLEGRO_PLAYMODE_ONCE, nil)
end

local function activate_token(token)
    local sc = token_scale
    local spr = token.top



    if token.type == TYPE_EARTH then
        play_element(TYPE_EARTH, token.pitch, 0.8, 0.0)
        anim(spr, spr.scale_x, spr.scale_x[1] + 0.4, spr.scale_x[1], Interp.INTERP_FAST, 0.3)
        anim(spr, spr.scale_y, spr.scale_y[1] + 0.4, spr.scale_y[1], Interp.INTERP_FAST, 0.3)
    elseif token.type == TYPE_WIND then
        play_element(TYPE_WIND, token.pitch, 0.8, 0.0)
        anim_full(spr, spr.scale_x, sc * 1.0, sc * 0.8, Interp.INTERP_SLOW_IN_OUT, 0.0, 0.5)
        anim_full(spr, spr.scale_x, sc * 0.8, sc * 1.0, Interp.INTERP_SLOW_IN_OUT, 0.5, 0.8)
        anim_full(spr, spr.scale_y, sc * 1.0, sc * 0.8, Interp.INTERP_SLOW_IN_OUT, 0.0, 0.5)
        anim_full(spr, spr.scale_y, sc * 0.8, sc * 1.0, Interp.INTERP_SLOW_IN_OUT, 0.5, 0.8)
        spawn_wind_effects(spr.x[1], spr.y[1])
    elseif token.type == TYPE_WATER then
        play_element(TYPE_WATER, token.pitch, 0.7, 0.5)
        anim_full(spr, spr.scale_x, sc * 1.3, sc * 0.8, Interp.INTERP_BOUNCE, 0.0, 0.5)
        anim_full(spr, spr.scale_x, sc * 0.8, sc * 1.0, Interp.INTERP_BOUNCE, 0.5, 0.5)
        anim_full(spr, spr.scale_y, sc * 0.8, sc * 1.3, Interp.INTERP_BOUNCE, 0.0, 0.5)
        anim_full(spr, spr.scale_y, sc * 1.3, sc * 1.0, Interp.INTERP_BOUNCE, 0.5, 0.5)
        spawn_water_effects(spr.x[1], spr.y[1])
    elseif token.type == TYPE_FIRE then
        play_element(TYPE_FIRE, token.pitch, 0.8, 0.0)
        anim(spr, spr.scale_x, sc * 1.3, sc, Interp.INTERP_SLOW_IN_OUT, 1.0)
        anim(spr, spr.scale_y, sc * 1.3, sc, Interp.INTERP_SLOW_IN_OUT, 1.0)
        spawn_fire_effects(spr.x[1], spr.y[1])
    end
end

local function update_playback()
    local y = 0

    for y = 0, TOKENS_Y - INDEX_BASE do
        activate_token(tokens[y * TOKENS_X + playback_column + INDEX_BASE])
    end

    playback_column = playback_column + 1
    if playback_column >= TOKENS_X then
        playback_column = 0
    end
end

--[[**************************************************************************--]]
--[[ Control                                                                  --]]
--[[**************************************************************************--]]

local function is_touched(token, size, x, y)
    local half = size / 2.0
    return (token.x - half <= x and x < token.x + half
        and token.y - half <= y and y < token.y + half)
end

local function get_touched_token(x, y)
    for i = 1, NUM_TOKENS do
        if is_touched(tokens[i], token_size, x, y) then
            return tokens[i]
        end
    end

    return nil
end

local function get_touched_button(x, y)
    for i = 1, NUM_TYPES do
        if is_touched(buttons[i], button_size, x, y) then
            return buttons[i]
        end
    end

    return nil
end

local function unselect_token(token)
    if token.type ~= TYPE_NONE then
        local spr = token.top
        anim_full(spr, spr.opacity, spr.opacity[1], 0.0, Interp.INTERP_SLOW, 0.15, 0.15)
        token.type = TYPE_NONE
    end
end

local function unselect_all_tokens()
    for i = 1, NUM_TOKENS do
        unselect_token(tokens[i])
    end
end

local function select_token(token)
    if not selected_button then
        return
    end

    local prev_type = token.type
    unselect_token(token)

    --[[ Unselect only if same type, for touch input. --]]
    if prev_type ~= selected_button.type then
        local spr = token.top
        spr.image = selected_button.type
        anim_to(spr, spr.opacity, 1.0, Interp.INTERP_FAST, 0.15)
        token.type = selected_button.type
    end
end

local function change_healthy_glow(_type, x)
    anim_tint(glow, glow_color[_type + INDEX_BASE], Interp.INTERP_SLOW_IN_OUT, 3.0)
    anim_to(glow, glow.x, x, Interp.INTERP_SLOW_IN_OUT, 3.0)

    anim_tint(glow_overlay, glow_color[_type + INDEX_BASE], Interp.INTERP_SLOW_IN_OUT, 4.0)
    anim_to(glow_overlay, glow_overlay.opacity, 1.0, Interp.INTERP_SLOW_IN_OUT, 4.0)
end

local function select_button(button)
    local spr

    if button == selected_button then
        return
    end

    if selected_button then
        spr = selected_button.top
        anim_to(spr, spr.scale_x, button_unsel_scale, Interp.INTERP_SLOW, 0.3)
        anim_to(spr, spr.scale_y, button_unsel_scale, Interp.INTERP_SLOW, 0.3)
        anim_to(spr, spr.opacity, 0.5, Interp.INTERP_DOUBLE_SLOW, 0.2)

        spr = selected_button.bot
        anim_to(spr, spr.scale_x, dropshadow_unsel_scale, Interp.INTERP_SLOW, 0.3)
        anim_to(spr, spr.scale_y, dropshadow_unsel_scale, Interp.INTERP_SLOW, 0.3)
    end

    selected_button = button

    spr = button.top
    anim_to(spr, spr.scale_x, button_sel_scale, Interp.INTERP_FAST, 0.3)
    anim_to(spr, spr.scale_y, button_sel_scale, Interp.INTERP_FAST, 0.3)
    anim_to(spr, spr.opacity, 1.0, Interp.INTERP_FAST, 0.3)

    spr = button.bot
    anim_to(spr, spr.scale_x, dropshadow_sel_scale, Interp.INTERP_FAST, 0.3)
    anim_to(spr, spr.scale_y, dropshadow_sel_scale, Interp.INTERP_FAST, 0.3)

    change_healthy_glow(button.type, button.x)

    allegro5.al_play_sample(select_sample, 1.0, 0.0, 1.0, allegro5.ALLEGRO_PLAYMODE_ONCE, nil)
end

local function on_mouse_down(x, y, mbut)
    local token
    local button

    if mbut == 1 then
        if (function()
                token = get_touched_token(x, y); return token
            end)() then
            select_token(token)
        elseif (function()
                button = get_touched_button(x, y); return button
            end)() then
            select_button(button)
        end
    elseif mbut == 2 then
        if (function()
                token = get_touched_token(x, y); return token
            end)() then
            unselect_token(token)
        end
    end
end

local function on_mouse_axes(x, y)
    local token = get_touched_token(x, y)

    if token == hover_token then
        return
    end

    if hover_token then
        local spr = hover_token.bot
        anim_to(spr, spr.opacity, 0.4, Interp.INTERP_DOUBLE_SLOW, 0.2)
    end

    hover_token = token

    if hover_token then
        local spr = hover_token.bot
        anim_to(spr, spr.opacity, 0.7, Interp.INTERP_FAST, 0.2)
    end
end

local function main_loop(queue)
    local event = allegro5.ALLEGRO_EVENT()
    local redraw = true

    while true do
        if redraw and allegro5.al_is_event_queue_empty(queue) then
            local now = allegro5.al_get_time()
            free_old_flairs(now)
            update_anims(now)
            draw_screen()
            redraw = false
        end

        allegro5.al_wait_for_event(queue, event)

        if event.timer.source == refresh_timer then
            redraw = true
        elseif event.timer.source == playback_timer then
            update_playback()
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_AXES then
            on_mouse_axes(event.mouse.x, event.mouse.y)
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
            on_mouse_down(event.mouse.x, event.mouse.y, event.mouse.button)
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end

            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_C then
                unselect_all_tokens()
            end
        end
    end
end

local function main()
    if not allegro5.al_init() then
        abort_example("Error initialising Allegro.\n")
    end

    open_log()

    if not allegro5.al_install_audio() or not allegro5.al_reserve_samples(128) then
        abort_example("Error initialising audio.\n")
    end
    allegro5.al_init_acodec_addon()
    allegro5.al_init_image_addon()
    init_platform_specific()

    allegro5.al_set_new_bitmap_flags(bit.bor(allegro5.ALLEGRO_MIN_LINEAR, allegro5.ALLEGRO_MAG_LINEAR))

    display = allegro5.al_create_display(screen_w, screen_h)
    if not display then
        abort_example("Error creating display.\n")
    end
    allegro5.al_set_window_title(display, "Haiku - A Musical Instrument")

    load_images()
    load_samples()

    init_tokens()
    init_buttons()
    init_glow()
    select_button(buttons[TYPE_EARTH + INDEX_BASE])

    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()

    refresh_timer = allegro5.al_create_timer(1.0 / refresh_rate)
    playback_timer = allegro5.al_create_timer(playback_period / TOKENS_X)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(refresh_timer))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(playback_timer))
    if allegro5.al_is_touch_input_installed() then
        allegro5.al_register_event_source(queue,
            allegro5.al_get_touch_input_mouse_emulation_event_source())
    end

    allegro5.al_start_timer(refresh_timer)
    allegro5.al_start_timer(playback_timer)

    main_loop(queue)

    free_all_flairs()

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
