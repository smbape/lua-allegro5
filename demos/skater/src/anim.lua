local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/anim.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local level = require("level")

local ObtainBitmap = level.ObtainBitmap
local ObtainSample = level.ObtainSample

local INDEX_BASE = 1 -- lua is 1-based indexed

local fabs = math.abs

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local game ---@module 'game'
local KEYFLAG_LEFT ---@type integer
local KEYFLAG_RIGHT ---@type integer

exports.init = function ()
    game = require("game")
    KEYFLAG_LEFT = game.KEYFLAG_LEFT
    KEYFLAG_RIGHT = game.KEYFLAG_RIGHT
end

---@class Animation
---@field Animation ALLEGRO_BITMAP[]
---@field Still ALLEGRO_BITMAP?
---@field Slow ALLEGRO_BITMAP?
---@field Medium ALLEGRO_BITMAP?
---@field Fast ALLEGRO_BITMAP?
---@field CBitmap ALLEGRO_BITMAP?
---@field SkateVoice ALLEGRO_SAMPLE_INSTANCE?
---@field TimeCount number
---@overload fun(\n
---   Animation?: ALLEGRO_BITMAP[],\n
---   Still?: ALLEGRO_BITMAP,\n
---   Slow?: ALLEGRO_BITMAP,\n
---   Medium?: ALLEGRO_BITMAP,\n
---   Fast?: ALLEGRO_BITMAP,\n
---   CBitmap?: ALLEGRO_BITMAP,\n
---   SkateVoice?: ALLEGRO_SAMPLE_INSTANCE,\n
---   TimeCount?: number): Animation
local Animation = common.class({
    __name = "Animation",

    ---@param self Animation
    ---@param Animation? ALLEGRO_BITMAP[]
    ---@param Still? ALLEGRO_BITMAP
    ---@param Slow? ALLEGRO_BITMAP
    ---@param Medium? ALLEGRO_BITMAP
    ---@param Fast? ALLEGRO_BITMAP
    ---@param CBitmap? ALLEGRO_BITMAP
    ---@param SkateVoice? ALLEGRO_SAMPLE_INSTANCE
    ---@param TimeCount? number
    __init__ = function(self, Animation, Still, Slow, Medium, Fast, CBitmap, SkateVoice, TimeCount)
        if Animation == nil then Animation = {} end
        if TimeCount == nil then TimeCount = 0 end
        self.Animation = Animation
        self.Still = Still
        self.Slow = Slow
        self.Medium = Medium
        self.Fast = Fast
        self.CBitmap = CBitmap
        self.SkateVoice = SkateVoice
        self.TimeCount = TimeCount
    end
})
exports.Animation = Animation


--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/anim.c
--]]

---@type number
local LastSpeedStore, LastSpeed = 0, 0

---@type boolean
local OnLand = false

---@param Anim Animation?
---@return ALLEGRO_BITMAP?
local function GetCurrentBitmap(Anim)
    if not Anim then
        return nil
    end

    LastSpeedStore = LastSpeed
    if Anim.SkateVoice then
        if LastSpeed >= 1.0 and OnLand then
            allegro5.al_set_sample_instance_gain(Anim.SkateVoice, 1.0 - (1.0 / LastSpeed))
        else
            allegro5.al_set_sample_instance_gain(Anim.SkateVoice, 0)
        end
    end

    return Anim.CBitmap
end
exports.GetCurrentBitmap = GetCurrentBitmap

---@param Anim Animation
---@param Distance number
---@param OnPlatform boolean
local function AdvanceAnimation(Anim, Distance, OnPlatform)
    Anim.TimeCount = Anim.TimeCount + Distance
    OnLand = OnPlatform

    if not OnPlatform then
        Anim.CBitmap = Anim.Fast
    else
        --[[ obtain speed --]]
        Distance = fabs(Distance); LastSpeed = Distance

        Anim.CBitmap = Anim.Fast
        if Distance < 12.0 and LastSpeedStore < 12.0 then
            Anim.CBitmap = Anim.Medium
        end
        if Distance < 5.0 and LastSpeedStore < 5.0 then
            Anim.CBitmap =
                (function()
                    if bit.band(game.KeyFlags, bit.bor(KEYFLAG_LEFT, KEYFLAG_RIGHT)) ~= 0 then
                        return Anim.Animation[math.floor(Anim.TimeCount) % 3 + INDEX_BASE]
                    else
                        return Anim.Slow
                    end
                end)()
        end
    end
end
exports.AdvanceAnimation = AdvanceAnimation

---@return Animation
local function SeedPlayerAnimation()
    local Anim = Animation()

    Anim.Animation[0 + INDEX_BASE] = ObtainBitmap("skater2")
    Anim.Animation[1 + INDEX_BASE] = ObtainBitmap("skater3")
    Anim.Animation[2 + INDEX_BASE] = ObtainBitmap("skater4")

    Anim.Still = ObtainBitmap("skater1"); Anim.CBitmap = Anim.Still
    Anim.Slow = ObtainBitmap("skateslow")
    Anim.Medium = ObtainBitmap("skatemed")
    Anim.Fast = ObtainBitmap("skatefast")

    local Sound = ObtainSample("skating")
    if Sound then
        Anim.SkateVoice = allegro5.al_create_sample_instance(Sound)
        allegro5.al_set_sample_instance_playmode(Anim.SkateVoice, allegro5.ALLEGRO_PLAYMODE_BIDIR)
    else
        Anim.SkateVoice = nil
    end

    return Anim
end
exports.SeedPlayerAnimation = SeedPlayerAnimation

---@param Anim? Animation
local function FreePlayerAnimation(Anim)
    if Anim and Anim.SkateVoice then
        allegro5.al_stop_sample_instance(Anim.SkateVoice)
        allegro5.al_destroy_sample_instance(Anim.SkateVoice)
    end
end
exports.FreePlayerAnimation = FreePlayerAnimation

---@param Anim Animation?
local function PauseAnimation(Anim)
    if Anim and Anim.SkateVoice then
        allegro5.al_stop_sample_instance(Anim.SkateVoice)
    end
end
exports.PauseAnimation = PauseAnimation

---@param Anim Animation?
local function UnpauseAnimation(Anim)
    if Anim and Anim.SkateVoice then
        allegro5.al_attach_sample_instance_to_mixer(Anim.SkateVoice, allegro5.al_get_default_mixer())
        allegro5.al_play_sample_instance(Anim.SkateVoice)
    end
end
exports.UnpauseAnimation = UnpauseAnimation

--[[
ALLEGRO_BITMAP *GetCurrentBitmap(struct Animation *Anim)
{
   return Anim->bmps[((int)Anim->TimeCount)&3];
}

void AdvanceAnimation(struct Animation *Anim, double Distance, int OnPlatform, int Forward)
{
   Anim->TimeCount += Distance*0.125f;
}

struct Animation *SeedPlayerAnimation(void)
{
   struct Animation *Anim = (struct Animation *)malloc(sizeof(struct Animation));
   Anim->bmps = (ALLEGRO_BITMAP **)malloc(sizeof(ALLEGRO_BITMAP *)*4);
   Anim->bmps[0] = load_bitmap("man-frame1.bmp", NULL);
   Anim->bmps[1] = load_bitmap("man-frame2.bmp", NULL);
   Anim->bmps[2] = load_bitmap("man-frame3.bmp", NULL);
   Anim->bmps[3] = load_bitmap("man-frame4.bmp", NULL);
   return Anim;
}

void FreePlayerAnimation(struct Animation *Anim)
{
   if(Anim) {
      if(Anim->bmps) {
         al_destroy_bitmap(Anim->bmps[0]);
         al_destroy_bitmap(Anim->bmps[1]);
         al_destroy_bitmap(Anim->bmps[2]);
         al_destroy_bitmap(Anim->bmps[3]);
         free((void *)Anim->bmps);
      }
      free(Anim);
   }
}
--]]

return exports
