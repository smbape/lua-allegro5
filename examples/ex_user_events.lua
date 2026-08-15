#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_user_events.c
--]]

--[[
 -    Example program for the Allegro library.
 --]]

local assert = require("luassert")
local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf

local calloc = allegro5_lua.C.calloc
local free = allegro5_lua.C.free

local ffi = allegro5_lua.ffi

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    ffi = require("ffi")
    calloc = ffi.C.calloc
    free = ffi.C.free
end

local voidptr_t = function(ptr)
    if not ptr or ptr == 0 then
        return nil
    end
    return ffi.cast("void*", ptr)
end

local intptr_t = function(ptr)
    return ffi.cast("intptr_t", ffi.cast("void*", ptr))
end

local MY_SIMPLE_EVENT_TYPE = allegro5.ALLEGRO_GET_EVENT_TYPE('m', 's', 'e', 't')
local MY_COMPLEX_EVENT_TYPE = allegro5.ALLEGRO_GET_EVENT_TYPE('m', 'c', 'e', 't')

ffi.cdef([[
/* Just some fantasy event, supposedly used in an RPG - it's just to show that
 * in practice, the 4 user fields we have now never will be enough. */
typedef struct MY_EVENT
{
    int id;
    int type; /* For example "attack" or "buy". */
    int x, y, z; /* Position in the game world the event takes place. */
    int server_time; /* Game time in ticks the event takes place. */
    int source_unit_id; /* E.g. attacker or seller. */
    int destination_unit_id; /* E.g. defender of buyer. */
    int item_id; /* E.g. weapon used or item sold. */
    int amount; /* Gold the item is sold for. */
} MY_EVENT;
]])

local MY_EVENT = ffi.typeof("MY_EVENT")
local MY_EVENT_PTR = ffi.typeof("MY_EVENT*")

local function new_event(id)
    local event = calloc(1, ffi.sizeof(MY_EVENT))
    local cdata = ffi.cast(MY_EVENT_PTR, event)
    cdata.id = id
    log_printf("my_event_ctor: %s\n", tostring(event))
    return event
end

local function my_event_dtor(event)
    local ptr = voidptr_t(event.data1)
    log_printf("my_event_dtor: %s\n", tostring(ptr))
    free(ptr)
end

local function main()
    local user_src = allegro5.ALLEGRO_EVENT_SOURCE()
    local user_event = allegro5.ALLEGRO_EVENT()
    local event = allegro5.ALLEGRO_EVENT()

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    local timer = allegro5.al_create_timer(0.5)
    if not timer then
        abort_example("Could not install timer.\n")
    end

    allegro5.al_init_user_event_source(user_src)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, user_src)
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_start_timer(timer)

    while true do
        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            local n = event.timer.count

            log_printf("Got timer event %d\n", n)

            user_event.user.type = MY_SIMPLE_EVENT_TYPE
            user_event.user.data1 = n
            allegro5.al_emit_user_event(user_src, user_event, nil)

            user_event.user.type = MY_COMPLEX_EVENT_TYPE
            user_event.user.data1 = intptr_t(new_event(n))
            allegro5.al_emit_user_event(user_src, user_event, my_event_dtor)
        elseif event.type == MY_SIMPLE_EVENT_TYPE then
            local n = event.user.data1
            assert.are.equal(event.user.source, user_src)

            allegro5.al_unref_user_event(event.user)

            log_printf("Got simple user event %d\n", n)
            if n == 5 then
                break
            end
        elseif event.type == MY_COMPLEX_EVENT_TYPE then
            local my_event = ffi.cast(MY_EVENT_PTR, voidptr_t(event.user.data1))
            assert.are.equal(event.user.source, user_src)

            log_printf("Got complex user event %d\n", my_event.id)
            allegro5.al_unref_user_event(event.user)
        else
            abort_example("Unknown event type %d.\n", event.type)
        end
    end

    allegro5.al_destroy_user_event_source(user_src)
    allegro5.al_destroy_event_queue(queue)
    allegro5.al_destroy_timer(timer)

    log_printf("Done.\n")
    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
