#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_blend_bench.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local open_log = common.open_log
local init_platform_specific = common.init_platform_specific
local close_log = common.close_log
local log_printf = common.log_printf

local clock = allegro5_lua.C.clock
local CLOCKS_PER_SEC = allegro5_lua.C.CLOCKS_PER_SEC

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    clock = ffi.C.clock
end

--[[
 -    Benchmark for memory blenders.
 --]]



--[[ Do a few un-timed runs to switch CPU to performance mode and cache
 - data and so on - seems to make the results more stable here.
 - Also used to guess the number of timed iterations.
 --]]
local WARMUP = 100
--[[ How many seconds the timing should approximately take - a fixed
 - number of iterations is not enough on very fast systems but takes
 - too long on slow systems.
 --]]
local TEST_TIME = 5.0

local Mode = {
   ALL = 1,
   PLAIN_BLIT = 2,
   SCALED_BLIT = 3,
   ROTATE_BLIT = 4,
}

local names = {
   "", "Plain blit", "Scaled blit", "Rotated blit"
}

local display

local function step(mode, b2)
   if mode == Mode.ALL then
      -- Nothing to do
   elseif mode == Mode.PLAIN_BLIT then
      allegro5.al_draw_bitmap(b2, 0, 0, 0)
   elseif mode == Mode.SCALED_BLIT then
      allegro5.al_draw_scaled_bitmap(b2, 0, 0, 320, 200, 0, 0, 640, 480, 0)
   elseif mode == Mode.ROTATE_BLIT then
      allegro5.al_draw_scaled_rotated_bitmap(b2, 10, 10, 10, 10, 2.0, 2.0,
         allegro5.ALLEGRO_PI / 30, 0)
   end
end

--[[ al_get_current_time() measures wallclock time - but for the benchmark
 - result we prefer CPU time so clock() is better.
 --]]
local function current_clock()
   local c = clock()
   return tonumber(c) / CLOCKS_PER_SEC
end

local function do_test(mode)
   local state = allegro5.ALLEGRO_STATE()
   local t0
   local t1

   allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)

   local b1 = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
   if not b1 then
      abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx\n")
      return false
   end

   local b2 = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/allegro.pcx")
   if not b2 then
      abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx\n")
      return false
   end

   allegro5.al_set_target_bitmap(b1)
   allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
   step(mode, b2)

   --[[ Display the blended bitmap to the screen so we can see something. --]]
   allegro5.al_store_state(state, allegro5.ALLEGRO_STATE_ALL)
   allegro5.al_set_target_backbuffer(display)
   allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
   allegro5.al_draw_bitmap(b1, 0, 0, 0)
   allegro5.al_flip_display()
   allegro5.al_restore_state(state)

   log_printf("Benchmark: %s\n", names[mode])
   log_printf("Please wait...\n")

   --[[ Do warmup run and estimate required runs for real test. --]]
   t0 = current_clock()
   for i = 1, WARMUP do
      step(mode, b2)
   end
   t1 = current_clock()
   local REPEAT = math.floor(TEST_TIME * 100 / (t1 - t0))

   --[[ Do the real test. --]]
   t0 = current_clock()
   for i = 1, REPEAT do
      step(mode, b2)
   end
   t1 = current_clock()

   log_printf("Time = %g s, %d steps\n",
      t1 - t0, REPEAT)
   log_printf("%s: %g FPS\n", names[mode], REPEAT / (t1 - t0))
   log_printf("Done\n")

   allegro5.al_destroy_bitmap(b1)
   allegro5.al_destroy_bitmap(b2)

   return true
end

local function main(argv)
   local argc = #argv

   local mode = Mode.ALL

   if argc >= 1 then
      local i = tonumber(argv[1])
      if i == 0 then
         mode = Mode.PLAIN_BLIT
      elseif i == 1 then
         mode = Mode.SCALED_BLIT
      elseif i == 2 then
         mode = Mode.ROTATE_BLIT
      end
   end

   if not allegro5.al_init() then
      abort_example("Could not init Allegro\n")
   end

   open_log()

   allegro5.al_init_image_addon()
   allegro5.al_init_primitives_addon()
   init_platform_specific()

   display = allegro5.al_create_display(640, 480)
   if not display then
      abort_example("Error creating display\n")
   end

   if mode == Mode.ALL then
      for mode = Mode.PLAIN_BLIT, Mode.ROTATE_BLIT do
         do_test(mode)
      end
   else
      do_test(mode)
   end

   allegro5.al_destroy_display(display)

   close_log(true)

   if allegro5.al_is_system_installed() then
      allegro5.al_uninstall_system()
   end
end

main(rawget(_G, "arg") or {})
