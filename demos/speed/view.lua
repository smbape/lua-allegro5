local exports = {}

local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/speed/view.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local a4_aux = require("a4_aux")
local badguys ---@module "badguys"
local bullets ---@module "bullets"
local explode ---@module "explode"
local hiscore ---@module "hiscore"
local message ---@module "message"
local player ---@module "player"
local speed = require("speed")

local new_table = common.new_table

local INDEX_BASE = 1 -- lua is 1-based indexed

local cos = math.cos
local log = math.log
local sin = math.sin

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local ABS = a4_aux.ABS
local MATRIX_f = a4_aux.MATRIX_f
local MIN = a4_aux.MIN
local SGN = a4_aux.SGN

local apply_matrix_f = a4_aux.apply_matrix_f
local get_scaling_matrix_f = a4_aux.get_scaling_matrix_f
local get_z_rotate_matrix_f = a4_aux.get_z_rotate_matrix_f
local line = a4_aux.line
local makecol = a4_aux.makecol
local matrix_mul_f = a4_aux.matrix_mul_f
local qtranslate_matrix_f = a4_aux.qtranslate_matrix_f
local solid_mode = a4_aux.solid_mode
local textprintf = a4_aux.textprintf

local draw_badguys ---@type fun(r: integer, g: integer, b: integer, project: fun(f: number[], i: integer[], c: integer):boolean)

local draw_bullets ---@type fun(r: integer, g: integer, b: integer, project: fun(f: number[], i: integer[], c: integer):boolean)

local draw_explode ---@type fun(r: integer, g: integer, b: integer, project: fun(f: number[], i: integer[], c: integer):boolean)

local get_hiscore ---@type fun() : integer

local draw_message ---@type fun()

local draw_player ---@type fun(r: integer, g: integer, b: integer, project: fun(f: number[], i: integer[], c: integer):boolean)
local player_pos ---@type fun() : integer

function exports.init()
    badguys = require("badguys")
    bullets = require("bullets")
    explode = require("explode")
    hiscore = require("hiscore")
    message = require("message")
    player = require("player")

    draw_badguys = badguys.draw_badguys

    draw_bullets = bullets.draw_bullets

    draw_explode = explode.draw_explode

    get_hiscore = hiscore.get_hiscore

    draw_message = message.draw_message

    draw_player = player.draw_player
    player_pos = player.player_pos

end

--[[
 -    SPEED - by Shawn Hargreaves, 1999
 -
 -    Viewport functions (3d projection, wireframe guide rendering, etc).
 --]]

local M_PI = 3.14159265358979323846


---@alias float4 [number, number, number, number]

---@class ViewPos
---@field pos float4 left, top, right, bottom
---@overload fun(pos? : float4): ViewPos
local ViewPos = common.class({
    __name = "ViewPos",

    ---@param self ViewPos
    ---@param pos? float4
    __init__ = function(self, pos)
        if pos == nil then pos = { 0, 0, 0, 0 } end
        self.pos = pos
    end
})

--[[ desired position of a viewport window --]]
---@class VIEWPOS
---@field [1] ViewPos left, top, right, bottom
---@field [2] ViewPos left, top, right, bottom
---@field [3] ViewPos left, top, right, bottom
---@field [4] ViewPos left, top, right, bottom
---@overload fun(view1? : [float4], view2? : [float4], view3? : [float4], view4? : [float4]): VIEWPOS
local VIEWPOS = common.class({
    __name = "VIEWPOS",

    ---@param self VIEWPOS
    ---@param view1? [float4]
    ---@param view2? [float4]
    ---@param view3? [float4]
    ---@param view4? [float4]
    __init__ = function(self, view1, view2, view3, view4)
        if view1 == nil then view1 = { { 0, 0, 0, 0 } } end
        if view2 == nil then view2 = { { 0, 0, 0, 0 } } end
        if view3 == nil then view3 = { { 0, 0, 0, 0 } } end
        if view4 == nil then view4 = { { 0, 0, 0, 0 } } end
        self[1] = ViewPos(unpack(view1))
        self[2] = ViewPos(unpack(view2))
        self[3] = ViewPos(unpack(view3))
        self[4] = ViewPos(unpack(view4))
    end
})

---@class ViewInfo
---@field pos float4 left, top, right, bottom
---@field vel float4 rate of change of the above
---@overload fun(pos? : float4): ViewInfo
local ViewInfo = common.class({
    __name = "ViewInfo",

    ---@param self ViewInfo
    ---@param pos? float4
    ---@param vel? float4
    __init__ = function(self, pos, vel)
        if pos == nil then pos = { 0, 0, 0, 0 } end
        if vel == nil then vel = { 0, 0, 0, 0 } end
        self.pos = pos
        self.vel = vel
    end
})

--[[ current status of a viewport window --]]
---@class VIEWINFO
---@field [1] ViewInfo left, top, right, bottom
---@field [2] ViewInfo left, top, right, bottom
---@field [3] ViewInfo left, top, right, bottom
---@field [4] ViewInfo left, top, right, bottom
---@overload fun(view_info1? : [float4], view_info2? : [float4], view_info3? : [float4], view_info4? : [float4]): VIEWINFO
local VIEWINFO = common.class({
    __name = "VIEWINFO",

    ---@param self VIEWINFO
    ---@param view_info1? [float4]
    ---@param view_info2? [float4]
    ---@param view_info3? [float4]
    ---@param view_info4? [float4]
    __init__ = function(self, view_info1, view_info2, view_info3, view_info4)
        if view_info1 == nil then view_info1 = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 } } end
        if view_info2 == nil then view_info2 = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 } } end
        if view_info3 == nil then view_info3 = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 } } end
        if view_info4 == nil then view_info4 = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 } } end
        self[1] = ViewInfo(unpack(view_info1))
        self[2] = ViewInfo(unpack(view_info2))
        self[3] = ViewInfo(unpack(view_info3))
        self[4] = ViewInfo(unpack(view_info4))
    end
})



--[[ viewport positioning macros --]]
local OFF_TL = { { -0.1, -0.1, -0.1, -0.1 } }
local OFF_TR = { { 1.1, -0.1, 1.1, -0.1 } }
local OFF_BL = { { -0.1, 1.1, -0.1, 1.1 } }
local OFF_BR = { { 1.1, 1.1, 1.1, 1.1 } }

local QTR_TL = { { 0, 0, 0.5, 0.5 } }
local QTR_TR = { { 0.5, 0, 1.0, 0.5 } }
local QTR_BL = { { 0, 0.5, 0.5, 1.0 } }
local QTR_BR = { { 0.5, 0.5, 1.0, 1.0 } }

local BIG_TL = { { 0, 0, 0.7, 0.7 } }
local BIG_TR = { { 0.3, 0, 1.0, 0.7 } }
local BIG_BL = { { 0, 0.3, 0.7, 1.0 } }
local BIG_BR = { { 0.3, 0.3, 1.0, 1.0 } }

local FULL = { { 0, 0, 1.0, 1.0 } }



--[[ list of viewport window positions --]]
local viewpos = new_table(VIEWPOS,
    {
        { FULL,   OFF_TR, OFF_BL, OFF_BR }, --[[ 1    single --]]
        { OFF_TL, FULL,   OFF_BL, OFF_BR }, --[[ 2    single --]]
        { BIG_TL, BIG_BR, OFF_BL, OFF_BR }, --[[ 12   multiple --]]
        { OFF_TL, OFF_TR, FULL,   OFF_BR }, --[[ 3    single --]]
        { BIG_TL, OFF_TR, BIG_BR, OFF_BR }, --[[ 13   multiple --]]
        { OFF_TL, BIG_TR, BIG_BL, OFF_BR }, --[[ 23   multiple --]]
        { FULL,   FULL,   OFF_BL, OFF_BR }, --[[ 12   superimpose --]]
        { OFF_TL, OFF_TR, OFF_BL, FULL, }, --[[ 4    single --]]
        { BIG_TL, OFF_TR, OFF_BL, BIG_BR }, --[[ 14   multiple --]]
        { OFF_TL, FULL,   FULL,   OFF_BR }, --[[ 23   superimpose --]]
        { OFF_TL, BIG_TL, OFF_BL, BIG_BR }, --[[ 24   multiple --]]
        { OFF_TL, FULL,   OFF_BL, FULL }, --[[ 24   superimpose --]]
        { QTR_TL, QTR_TR, QTR_BL, OFF_BR }, --[[ 123  multiple --]]
        { BIG_TL, OFF_TR, OFF_BL, BIG_BR }, --[[ 14   superimpose --]]
        { QTR_TL, OFF_TR, QTR_BL, QTR_BR }, --[[ 134  multiple --]]
        { FULL,   OFF_TR, FULL,   OFF_BR }, --[[ 13   superimpose --]]
        { OFF_TL, OFF_TR, BIG_TL, BIG_BR }, --[[ 34   multiple --]]
        { OFF_TL, QTR_TR, BIG_BL, QTR_BR }, --[[ 234  multiple --]]
        { OFF_TL, OFF_TR, FULL,   FULL }, --[[ 34   superimpose --]]
        { FULL,   QTR_TR, OFF_BL, QTR_BR }, --[[ 124  multiple --]]
        { FULL,   FULL,   OFF_BL, FULL }, --[[ 124  superimpose --]]
        { QTR_TL, QTR_TR, QTR_BL, QTR_BR }, --[[ 1234 multiple --]]
        { FULL,   FULL,   FULL,   OFF_BR }, --[[ 123  superimpose --]]
        { FULL,   OFF_TR, FULL,   FULL }, --[[ 134  superimpose --]]
        { OFF_TL, FULL,   FULL,   FULL }, --[[ 234  superimpose --]]
        { FULL,   FULL,   FULL,   FULL }, --[[ 1234 superimpose --]]
    })



--[[ current viewport state --]]
local viewinfo = VIEWINFO()

local viewnum = 0 ---@type integer

local view_left, view_top, view_right, view_bottom = 0, 0, 0, 0 ---@type number, number, number, number



--[[ returns a scaling factor for 2d graphics effects --]]
local function view_size()
    return ((view_right - view_left) + (view_bottom - view_top)) / 2
end
exports.view_size = view_size



--[[ initialises the view functions --]]
local function init_view()
    viewnum = 0

    for i = 1, 4 do
        for j = 1, 4 do
            viewinfo[i].pos[j] = 0
            viewinfo[i].vel[j] = 0
        end
    end
end
exports.init_view = init_view



--[[ closes down the view module --]]
local function shutdown_view()
end
exports.shutdown_view = shutdown_view



--[[ advances to the next view position --]]
local function advance_view()
    local cycled = false

    viewnum = viewnum + 1

    if viewnum >= #viewpos then
        viewnum = 0
        cycled = true
    end

    return cycled
end
exports.advance_view = advance_view



--[[ updates the view position --]]
local function update_view()
    for i = 1, 4 do
        for j = 1, 4 do
            local delta = viewpos[viewnum + INDEX_BASE][i].pos[j] - viewinfo[i].pos[j]
            local vel = viewinfo[i].vel[j]

            vel = vel * (0.9)
            delta = log(ABS(delta) + 1.0) * SGN(delta) / 64.0
            vel = vel + (delta)

            if (ABS(delta) < 0.00001) and (ABS(vel) < 0.00001) then
                viewinfo[i].pos[j] = viewpos[viewnum + INDEX_BASE][i].pos[j]
                viewinfo[i].vel[j] = 0
            else
                viewinfo[i].pos[j] = viewinfo[i].pos[j] + (vel)
                viewinfo[i].vel[j] = vel
            end
        end
    end
end
exports.update_view = update_view



--[[ flat projection function --]]
---@param f integer[]
---@param i integer[]
---@param c integer
---@return boolean
local function project_flat(f, i, c)
    local f_offset = 0 ---@type integer
    local i_offset = 0 ---@type integer

    while c > 0 do
        i[0 + INDEX_BASE + i_offset] = math.floor(view_left + f[0 + INDEX_BASE + f_offset] * (view_right - view_left))
        i[1 + INDEX_BASE + i_offset] = math.floor(view_top + f[1 + INDEX_BASE + f_offset] * (view_bottom - view_top))

        f_offset = f_offset + (2) ---@type integer
        i_offset = i_offset + (2) ---@type integer
        c = c - (2)
    end

    return true
end



--[[ spherical coordinate projection function --]]
---@param f integer[]
---@param i integer[]
---@param c integer
---@return boolean
local function project_spherical(f, i, c)
    local f_offset = 0 ---@type integer
    local i_offset = 0 ---@type integer

    while c > 0 do
        local ang = f[0 + INDEX_BASE + f_offset] * M_PI * 2.0

        local xsize = view_right - view_left
        local ysize = view_bottom - view_top
        local size = MIN(xsize, ysize) / 2.0

        local ff = (function() if (f[1 + INDEX_BASE + f_offset] > 0.99) then return 0 else return (1.0 - f[1 + INDEX_BASE + f_offset] * 0.9) end end)()

        local dx = cos(ang) * ff * size
        local dy = sin(ang) * ff * size

        i[0 + INDEX_BASE + i_offset] = math.floor(dx + (view_left + view_right) / 2.0)
        i[1 + INDEX_BASE + i_offset] = math.floor(dy + (view_top + view_bottom) / 2.0)

        f_offset = f_offset + (2) ---@type integer
        i_offset = i_offset + (2) ---@type integer
        c = c - (2)
    end

    return true
end



--[[ inside of tube projection function --]]
---@param f integer[]
---@param i integer[]
---@param c integer
---@return boolean
local function project_tube(f, i, c)
    local f_offset = 0 ---@type integer
    local i_offset = 0 ---@type integer

    while c > 0 do
        local ang = f[0 + INDEX_BASE + f_offset] * M_PI * 2.0 + M_PI / 2.0

        local xsize = view_right - view_left
        local ysize = view_bottom - view_top
        local size = MIN(xsize, ysize) / 2.0

        local x = cos(ang)
        local y = sin(ang)

        local z = 1.0 + (1.0 - f[1 + INDEX_BASE + f_offset]) * 8.0

        i[0 + INDEX_BASE + i_offset] = math.floor(x / z * size + (view_left + view_right) / 2.0)
        i[1 + INDEX_BASE + i_offset] = math.floor(y / z * size + (view_top + view_bottom) / 2.0)

        f_offset = f_offset + (2) ---@type integer
        i_offset = i_offset + (2) ---@type integer
        c = c - (2)
    end

    return true
end



local mtx = MATRIX_f()
local virgin = true

--[[ outside of cylinder projection function --]]
---@param f integer[]
---@param i integer[]
---@param c integer
---@return boolean
local function project_cylinder(f, i, c)
    if virgin then
        local m1 = get_z_rotate_matrix_f(-64)
        qtranslate_matrix_f(m1, 0, 1.75, 0)
        local m2 = get_scaling_matrix_f(2.0, 1.0, 1.0)
        matrix_mul_f(m1, m2, mtx)

        virgin = false
    end

    local f_offset = 0 ---@type integer
    local i_offset = 0 ---@type integer

    while c > 0 do
        local ang = (f[0 + INDEX_BASE + f_offset] - player_pos()) * M_PI * 2.0

        local xsize = view_right - view_left
        local ysize = view_bottom - view_top
        local size = MIN(xsize, ysize) / 2.0

        local x = cos(ang)
        local y = sin(ang)
        local z = 1.0 + (1.0 - f[1 + INDEX_BASE + f_offset]) * 4.0

        local xout, yout, zout = apply_matrix_f(mtx, x, y, z)

        if yout > 1.5 then
            return false
        end

        i[0 + INDEX_BASE + i_offset] = math.floor(xout / zout * size + (view_left + view_right) / 2.0)
        i[1 + INDEX_BASE + i_offset] = math.floor((yout / zout * 2 - 1) * size + (view_top + view_bottom) / 2.0)

        f_offset = f_offset + (2) ---@type integer
        i_offset = i_offset + (2) ---@type integer
        c = c - (2)
    end

    return true
end



--[[ draws the entire view --]]
local function draw_view()
    local SCREEN_W = allegro5.al_get_display_width(a4_aux.screen)
    local SCREEN_H = allegro5.al_get_display_height(a4_aux.screen)
    local project ---@type fun(f : number[], i : integer[], c : integer) : boolean
    local r, g, b = 0, 0, 0 ---@type integer, integer, integer
    local point = new_table(0.0, 6)
    local ipoint = new_table(0, 6)

    allegro5.al_clear_to_color(makecol(0, 0, 0))

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)

    for i = 0, 4 - INDEX_BASE do
        view_left   = viewinfo[i + INDEX_BASE].pos[0 + INDEX_BASE] * SCREEN_W
        view_top    = viewinfo[i + INDEX_BASE].pos[1 + INDEX_BASE] * SCREEN_H
        view_right  = viewinfo[i + INDEX_BASE].pos[2 + INDEX_BASE] * SCREEN_W
        view_bottom = viewinfo[i + INDEX_BASE].pos[3 + INDEX_BASE] * SCREEN_H

        if (view_right > view_left) and (view_bottom > view_top) and
            (view_right > 0) and (view_bottom > 0) and
            (view_left < SCREEN_W) and (view_top < SCREEN_H) then
            if i == 0 then
                --[[ flat projection, green --]]
                project = project_flat

                r = 0
                g = 255
                b = 0
            elseif i == 1 then
                --[[ spherical coordinates, yellow --]]
                project = project_spherical

                r = 255
                g = 255
                b = 0
            elseif i == 2 then
                --[[ inside a tube, blue --]]
                project = project_tube

                r = 0
                g = 0
                b = 255
            elseif i == 3 then
                --[[ surface of cylinder, red --]]
                project = project_cylinder

                r = 255
                g = 0
                b = 0
            else
                --[[ oops! --]]
                assert(false)
                return
            end

            if not speed.no_grid then
                local c = makecol(math.floor(r / 5), math.floor(g / 5), math.floor(b / 5))

                local n = (function() if (speed.low_detail) then return 8 else return 16 end end)() ---@type integer

                for x = 0, n do
                    for y = 0, n do
                        point[0 + INDEX_BASE] = x / n
                        point[1 + INDEX_BASE] = y / n
                        point[2 + INDEX_BASE] = (x + 1) / n
                        point[3 + INDEX_BASE] = y / n
                        point[4 + INDEX_BASE] = x / n
                        point[5 + INDEX_BASE] = (y + 1) / n

                        if project(point, ipoint, 6) then
                            if x < n then
                                line(ipoint[0 + INDEX_BASE], ipoint[1 + INDEX_BASE], ipoint[2 + INDEX_BASE], ipoint[3 + INDEX_BASE], c)
                            end

                            if (y < n) and ((x < n) or (i == 0)) then
                                line(ipoint[0 + INDEX_BASE], ipoint[1 + INDEX_BASE], ipoint[4 + INDEX_BASE], ipoint[5 + INDEX_BASE], c)
                            end
                        end
                    end
                end
            end

            draw_player(r, g, b, project)
            draw_badguys(r, g, b, project)
            draw_bullets(r, g, b, project)
            draw_explode(r, g, b, project)
        end
    end

    solid_mode()

    draw_message()

    textprintf(a4_aux.font_video, 4, 4, makecol(128, 128, 128), "Lives: %d", speed.lives)
    textprintf(a4_aux.font_video, 4, 16, makecol(128, 128, 128), "Score: %d", speed.score)
    textprintf(a4_aux.font_video, 4, 28, makecol(128, 128, 128), "Hiscore: %d", get_hiscore())

    allegro5.al_flip_display()
end
exports.draw_view = draw_view

return exports
