#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_noframe.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
   allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local function main()
   local event = allegro5.ALLEGRO_EVENT()
   local down = false
   local down_x, down_y = 0, 0

   if not allegro5.al_init() then
      abort_example("Could not init Allegro.\n")
   end

   allegro5.al_install_mouse()
   allegro5.al_install_keyboard()
   allegro5.al_init_image_addon()
   init_platform_specific()

   allegro5.al_set_new_display_flags(allegro5.ALLEGRO_FRAMELESS)
   local display = allegro5.al_create_display(300, 200)
   if not display then
      abort_example("Error creating display\n")
   end

   local bitmap = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fakeamp.bmp")
   if not bitmap then
      abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fakeamp.bmp\n")
   end

   local timer = allegro5.al_create_timer(1.0 / 30.0)

   local events = allegro5.al_create_event_queue()
   allegro5.al_register_event_source(events, allegro5.al_get_mouse_event_source())
   allegro5.al_register_event_source(events, allegro5.al_get_keyboard_event_source())
   allegro5.al_register_event_source(events, allegro5.al_get_display_event_source(display))
   allegro5.al_register_event_source(events, allegro5.al_get_timer_event_source(timer))

   allegro5.al_start_timer(timer)

   while true do
      allegro5.al_wait_for_event(events, event)
      if event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
         if event.mouse.button == 1 and event.mouse.x then
            down = true
            down_x = event.mouse.x
            down_y = event.mouse.y
         end
         if event.mouse.button == 2 then
            allegro5.al_set_display_flag(display, allegro5.ALLEGRO_FRAMELESS,
               not (bit.band(allegro5.al_get_display_flags(display), allegro5.ALLEGRO_FRAMELESS)))
         end
      elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
         break
      elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_UP then
         if event.mouse.button == 1 then
            down = false
         end
      elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_AXES then
         if down then
            local success, cx, cy = allegro5.al_get_mouse_cursor_position()
            if success then
               allegro5.al_set_window_position(display, cx - down_x, cy - down_y)
            end
         end
      elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN and
          event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
         break
      elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
         allegro5.al_draw_bitmap(bitmap, 0, 0, 0)
         allegro5.al_flip_display()
      end
   end

   allegro5.al_destroy_timer(timer)
   allegro5.al_destroy_event_queue(events)
   allegro5.al_destroy_display(display)

   if allegro5.al_is_system_installed() then
      allegro5.al_uninstall_system()
   end
end

main()
