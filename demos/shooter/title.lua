local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/shooter/title.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local a4_aux = require("demos.speed.a4_aux")
local data_m = require("data")
local demo = require("demo")
local star = require("star")

local copy = common.copy

local env = common.env

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local ABS = a4_aux.ABS
local MIN = a4_aux.MIN
local blit = a4_aux.blit
local clear_keybuf = a4_aux.clear_keybuf
local draw_sprite = a4_aux.draw_sprite
local fixcos = a4_aux.fixcos
local fixmul = a4_aux.fixmul
local fixsin = a4_aux.fixsin
local fixsqrt = a4_aux.fixsqrt
local fixtoi = a4_aux.fixtoi
local itofix = a4_aux.itofix
local keypressed = a4_aux.keypressed
local makecol = a4_aux.makecol
local play_midi = a4_aux.play_midi
local play_sample = a4_aux.play_sample
local poll_input = a4_aux.poll_input
local readkey = a4_aux.readkey
local rectfill = a4_aux.rectfill
local rest = a4_aux.rest
local stretch_blit = a4_aux.stretch_blit
local text_height = a4_aux.text_height
local text_length = a4_aux.text_length
local textout = a4_aux.textout
local textprintf = a4_aux.textprintf


local END_FONT = data_m.END_FONT
local TITLE_BMP = data_m.TITLE_BMP
local TITLE_FONT = data_m.TITLE_FONT
local TITLE_MUSIC = data_m.TITLE_MUSIC
local TITLE_PAL = data_m.TITLE_PAL
local WELCOME_SPL = data_m.WELCOME_SPL
local data = data_m.data

local PAL_SIZE = demo.PAL_SIZE
local PALETTE = demo.PALETTE
local fade_out = demo.fade_out
local get_palette = demo.get_palette
local set_palette = demo.set_palette

local draw_starfield_3d = star.draw_starfield_3d
local init_starfield_3d = star.init_starfield_3d
local starfield_3d = star.starfield_3d

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/shooter/title.c
--]]

--[[ for parsing readme.txt --]]
---@class README_SECTION
---@field desc? string
---@field texts string[]
---@field flat? string
---@overload fun(desc?: string): README_SECTION
local README_SECTION = common.class({
    __name = "README_SECTION",

    ---@param self README_SECTION
    ---@param desc? string
    __init__ = function(self, desc)
        self.desc = desc
        self.texts = {}
    end
})

--[[ for parsing thanks._tx and the various source files --]]
---@class CREDIT_NAME
---@field name? string
---@field text? string
---@field files string[]
---@overload fun(name?: string, text?: string, files?: string[]): CREDIT_NAME
local CREDIT_NAME = common.class({
    __name = "CREDIT_NAME",

    ---@param self CREDIT_NAME
    ---@param name? string
    ---@param text? string
    ---@param files? string[]
    __init__ = function(self, name, text, files)
        if files == nil then files = {} end
        self.name = name
        self.text = text
        self.files = files
    end
})

--[[ text messages (loaded from readme.txt) --]]
local title_text = "" ---@type string
local title_size = 0 ---@type integer

local title_palette = PALETTE()

--[[ author credits scroller --]]
local credit_width = 0 ---@type integer
local credit_scroll = 0 ---@type integer
local credit_offset = 0 ---@type integer
local credit_age = 0 ---@type integer
local credit_speed = 32 ---@type integer
local credit_skip = 1 ---@type integer

--[[ text scroller at the bottom --]]
local text_scroll = 0 ---@type integer
local text_char = 0 ---@type integer
local text_pix = 0 ---@type integer
local text_width = 0 ---@type integer

local credit_name ---@type CREDIT_NAME?
local credit_index = 1 ---@type integer

local credits = {} ---@type CREDIT_NAME[]
local text ---@type ALLEGRO_CONFIG?


--[[ reads credit info from various places --]]
local function load_credits()
    -- exported the result from the original scanning which scanned all
    -- source files to a static text.ini with the ancient A4 credits :)
    -- (the original only worked when running from the A4 source folder)
    text = allegro5.al_load_config_file(env.ALLEGRO_DEMOS_SHOOTER_DATA_PATH .. "/text.ini")
    local i = -1 ---@type integer
    while true do
        i = i + 1
        local k = string.format("%d", i)
        local vn = allegro5.al_get_config_value(text, "credits", k)
        if not vn then
            break
        end
        local c = CREDIT_NAME()
        c.name = vn

        k = string.format("%d_0", i)
        local v0 = allegro5.al_get_config_value(text, "credits", k)
        c.text = v0
        local j = 0 ---@type integer
        while true do
            j = j + 1 ---@type integer
            k = string.format("%d_%d", i, j)
            local v = allegro5.al_get_config_value(text, "credits", k)
            if not v then
                break
            end
            c.files[#c.files + 1] = v
        end
        credits[#credits + 1] = c
    end
    title_text = allegro5.al_get_config_value(text, "readme", "text") ---@diagnostic disable-line: cast-local-type
    if not title_text then
        title_text = ""
    end
    title_size = #title_text
end



local function scroller()
    starfield_3d()

    --[[ move the scroller at the bottom --]]
    text_scroll = text_scroll + (4)

    --[[ update the credits position --]]
    if credit_scroll <= 0 then
        if credit_name then
            credit_index = credit_index + 1
            credit_name = credits[credit_index]
        end

        if not credit_name then
            credit_index = 1
            credit_name = credits[credit_index]
        end

        if credit_name then
            credit_width =
                text_length(data[END_FONT + INDEX_BASE].dat, credit_name.name) + 24

            if credit_name.text then
                credit_scroll = allegro5.al_get_text_width(data[TITLE_FONT + INDEX_BASE].dat, credit_name.text) +
                    demo.SCREEN_W -
                    credit_width
            else
                credit_scroll = 256
            end

            credit_offset = demo.SCREEN_W - credit_scroll

            credit_age = 0
        end
    else
        credit_scroll = credit_scroll - (4)
        credit_age = credit_age + (4)
    end
end



local function draw_scroller()
    local bigfont = data[TITLE_FONT + INDEX_BASE].dat ---@type ALLEGRO_FONT
    local th = text_height(bigfont)

    --[[ draw the text scroller at the bottom --]]
    textout(bigfont, title_text,
        demo.SCREEN_W - text_scroll, demo.SCREEN_H - th, makecol(255, 255, 255))

    --[[ draw author file credits --]]
    if credit_name then
        local n = credit_width ---@type integer
        local n2 = 0 ---@type integer

        for _, tl_text in ipairs(credit_name.files) do
            local c = 1024 + n2 * credit_speed - credit_age ---@type integer

            if (c > 0) and (c < 1024) and ((n2 % credit_skip) == 0) then
                local x = itofix(math.floor(demo.SCREEN_W / 2)) ---@type integer
                local y = itofix(math.floor(demo.SCREEN_H / 2) - 32) ---@type integer

                local c2 = math.floor(c * (math.floor(n / 13) % 17 + 1) / 32) ---@type integer
                if bit.band(n, 1) ~= 0 then
                    c2 = -c2
                end

                c2 = c2 - (96)

                ---@type integer
                local c3 = math.floor((32 +
                    fixtoi(ABS(fixsin(itofix(math.floor(c / (15 + n % 42)) + n))) *
                        128)) * demo.SCREEN_W / 640)

                x = x + fixsin(itofix(c2)) * c3
                y = y + fixcos(itofix(c2)) * c3

                if c < 512 then
                    local z = fixsqrt(math.floor(itofix(c) / 512)) ---@type integer

                    x = fixmul(itofix(32), itofix(1) - z) + fixmul(x, z)
                    y = fixmul(itofix(16), itofix(1) - z) + fixmul(y, z)
                elseif c > 768 then
                    local z = fixsqrt(math.floor(itofix(1024 - c) / 256)) ---@type integer

                    if bit.band(n, 2) ~= 0 then
                        x = fixmul(itofix(128), itofix(1) - z) + fixmul(x, z)
                    else
                        x = fixmul(itofix(demo.SCREEN_W - 128),
                            itofix(1) - z) + fixmul(x, z)
                    end

                    y = fixmul(itofix(demo.SCREEN_H - 128),
                        itofix(1) - z) + fixmul(y, z)
                end

                c = 128 + math.floor((512 - ABS(512 - c)) / 24)
                c = MIN(255, math.floor(c * 1.25))

                local ix = fixtoi(x) ---@type integer
                local iy = fixtoi(y) ---@type integer

                c2 = #tl_text
                ix = ix - (c2 * 4)

                textout(bigfont, tl_text, ix, iy, get_palette(c))
            end

            n = n + (1234567) ---@type integer
            n2 = n2 + 1
        end
    end

    draw_starfield_3d()

    --[[ draw author name/desc credits --]]
    if credit_name then
        if credit_name.text then
            local c = credit_scroll + credit_offset ---@type integer
            local p = credit_name.text ---@type string
            local c2 = #p

            textout(bigfont, p, c, 16, get_palette(255))
        end

        local c = 4 ---@type integer

        if credit_age < 100 then
            ---@type integer
            c = c - math.floor((100 - credit_age) * (100 -
                credit_age) * credit_width / 10000)
        end

        if credit_scroll < 150 then
            c = c + math.floor((150 - credit_scroll) * (150 -
                    credit_scroll) * demo.SCREEN_W /
                22500)
        end

        rectfill(0, 0, credit_width, 60, makecol(0, 0, 0))
        textprintf(data[END_FONT + INDEX_BASE].dat, c, 4, makecol(255, 255, 255), "%s:",
            credit_name.name)
    end

    --[[ draw the Allegro logo over the top --]]
    draw_sprite(data[TITLE_BMP + INDEX_BASE].dat, math.floor(demo.SCREEN_W / 2) - 160,
        math.floor(demo.SCREEN_H / 2) - 96)
end


local color = 0 ---@type integer

--[[ displays the title screen --]]
---@return boolean
local function title_screen()
    local updated = false ---@type boolean
    local scroll_pos = 0 ---@type integer

    text_scroll = 0
    credit_width = 0
    credit_scroll = 0
    credit_offset = 0
    credit_age = 0
    credit_speed = 32
    credit_skip = 1

    text_char = -1
    text_pix = 0
    text_width = 0

    play_midi(data[TITLE_MUSIC + INDEX_BASE].dat, true)
    play_sample(data[WELCOME_SPL + INDEX_BASE].dat, 255, 127, 1000, false)

    load_credits()

    init_starfield_3d()

    for c = 1, 8 do
        title_palette.rgb[c] = copy(allegro5.ALLEGRO_COLOR, data[TITLE_PAL + INDEX_BASE].dat --[[@as PALETTE --]].rgb[c])
    end

    --/* set up the colors differently each time we display the title screen */
    for c = 9, math.floor(PAL_SIZE / 2) do
        local rgb = copy(allegro5.ALLEGRO_COLOR, data[TITLE_PAL + INDEX_BASE].dat --[[@as PALETTE --]].rgb[c]) ---@type ALLEGRO_COLOR
        if color == 0 then
            rgb.b = rgb.r
            rgb.r = 0
        elseif color == 1 then
            rgb.g = rgb.r
            rgb.r = 0
        elseif color == 3 then
            rgb.g = rgb.r
        end
        title_palette.rgb[c] = rgb
    end

    for c = math.floor(PAL_SIZE / 2) + INDEX_BASE, PAL_SIZE do
        ---@type allegro5.ALLEGRO_COLOR
        local rgb = copy(allegro5.ALLEGRO_COLOR, data[TITLE_PAL + INDEX_BASE].dat --[[ @as PALETTE --]].rgb[c])
        title_palette.rgb[c] = rgb
    end

    color = color + 1
    if color > 3 then
        color = 0
    end

    allegro5.al_clear_to_color(makecol(0, 0, 0))

    set_palette(title_palette)

    local c = 1 ---@type integer
    while c < 160 do
        stretch_blit(data[TITLE_BMP + INDEX_BASE].dat, 0, 0, 320, 128,
            math.floor(demo.SCREEN_W / 2) - c, math.floor(demo.SCREEN_H / 2) - math.floor(c * 64 / 160) - 32,
            c * 2, math.floor(c * 128 / 160))
        rest(5)
        c = c + 1
    end

    blit(data[TITLE_BMP + INDEX_BASE].dat, 0, 0, math.floor(demo.SCREEN_W / 2) - 160,
        math.floor(demo.SCREEN_H / 2) - 96, 320, 128)

    clear_keybuf()

    repeat
        updated = false

        scroller()
        scroll_pos = scroll_pos + 1 ---@type integer
        updated = true

        if demo.max_fps or updated then
            allegro5.al_clear_to_color(makecol(0, 0, 0))
            draw_scroller()
            allegro5.al_flip_display()
        end

        poll_input()
        rest(1)
    until keypressed(); -- && (!joy[0].button[0].b) && (!joy[0].button[1].b));


    fade_out(5)

    while keypressed() do
        if bit.band(readkey(), 0xff) == 27 then
            return false
        end
    end

    return true
end
exports.title_screen = title_screen


return exports
