#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_timer_pause.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ A test of pausing/resuming a timer.
 -
 - 1. Create two 5s long timers.
 - 2. Let each run for 2s, then stop each for 2s.
 - 3. Call al_resume_timer on timer1 and al_start_timer on timer2
 - 4. Wait for timer events
 -
 - timer1 should finish before timer2, as it was resumed rather than restarted.
 --]]

--[[ Run our test. --]]
local function main()
    local duration  = 5 -- timer lasts for 5 seconds
    local pre_pause = 2 -- how long to wait before pausing
    local pause     = 2 -- how long to pause timer for

    local ev        = allegro5.ALLEGRO_EVENT()

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    -- Initializes and displays a log window for debugging purposes.
    open_log()

    log_printf("Creating a pair of %2.0fs timers\n", duration)
    local queue = allegro5.al_create_event_queue()
    local timer1 = allegro5.al_create_timer(duration)
    local timer2 = allegro5.al_create_timer(duration)
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer1))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer2))

    log_printf("Starting both timers at: %2.2fs\n", allegro5.al_get_time() * 100)
    allegro5.al_start_timer(timer1)
    allegro5.al_start_timer(timer2)
    allegro5.al_rest(pre_pause)

    log_printf("Pausing timers at: %2.2fs\n", allegro5.al_get_time() * 100)
    allegro5.al_stop_timer(timer1)
    allegro5.al_stop_timer(timer2)
    allegro5.al_rest(pause)

    log_printf("Resume  timer1 at: %2.2fs\n", allegro5.al_get_time() * 100)
    allegro5.al_resume_timer(timer1)

    log_printf("Restart timer2 at: %2.2fs\n", allegro5.al_get_time() * 100)
    allegro5.al_start_timer(timer2)

    allegro5.al_wait_for_event(queue, ev)
    log_printf("Timer%d finished at: %2.2fs\n",
        (function() if allegro5.al_get_timer_event_source(timer1) == ev.any.source then return 1 else return 2 end end)(),
        allegro5.al_get_time() * 100)

    allegro5.al_wait_for_event(queue, ev)
    log_printf("Timer%d finished at: %2.2fs\n",
        (function() if allegro5.al_get_timer_event_source(timer1) == ev.any.source then return 1 else return 2 end end)(),
        allegro5.al_get_time() * 100)

    allegro5.al_destroy_event_queue(queue)
    allegro5.al_destroy_timer(timer1)
    allegro5.al_destroy_timer(timer2)

    close_log(false)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
