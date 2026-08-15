const fs = require("node:fs");
const sysPath = require("node:path");
const os = require("node:os");
const custom_declarations = require("./custom_declarations");

const al5_functions = fs.readFileSync(sysPath.resolve(__dirname, "../allegro5_lua/al5_functions.lua")).toString().trim();

const isCharType = (type, modifiers) => {
    return type === "char";
};

const isOutArg = (type, modifiers) => {
    return modifiers.includes("/O") || modifiers.includes("/IO");
};

const isStringType = (type, modifiers) => {
    if (modifiers.includes("/WrapAs=const_cast<char*>")) {
        return false;
    }

    if (/^(?:const\s+char|char\s+const)\s*\*$/.test(type)) {
        return true;
    }

    return type.endsWith("*") && type.slice(0, -1).trim() === "char" && modifiers.includes("/C");
};

const isVoidPtrType = (type, modifiers) => {
    return type.endsWith("*")
        && type.slice(0, -1).trim() === "void";
};

const LUA_RESERVED_KEYWORDS = new Set([
    "and",
    "elseif",
    "end",
    "in",
    "local",
    "nil",
    "not",
    "or",
    "repeat",
    "until",
]);

const toArgument = ([argtype, argname]) => {
    if (argtype === "...") {
        return "...";
    }

    if (LUA_RESERVED_KEYWORDS.has(argname)) {
        return `_${ argname }`;
    }

    return argname;
};

const asm = new Map(os.platform() === "win32" ? [
    ["ctime", "_ctime64"],
    ["difftime", "_difftime64"],
    ["gmtime", "_gmtime64"],
    ["localtime", "_localtime64"],
    ["mktime", "_mktime64"],
    ["time", "_time64"],
    ["timespec_get", "_timespec64_get"],
    ["gmtime_s", "_gmtime64_s"],
    ["localtime_s", "_localtime64_s"],
] : []);

const LUA_KEYWORDS = new Set([
    ...LUA_RESERVED_KEYWORDS,

    // https://www.lua.org/manual/5.1/index.html#index
    // Lua functions
    "_G",
    "_VERSION",
    "assert",
    "collectgarbage",
    "dofile",
    "error",
    "getfenv",
    "getmetatable",
    "ipairs",
    "load",
    "loadfile",
    "loadstring",
    "module",
    "next",
    "pairs",
    "pcall",
    "print",
    "rawequal",
    "rawget",
    "rawset",
    "require",
    "select",
    "setfenv",
    "setmetatable",
    "tonumber",
    "tostring",
    "type",
    "unpack",
    "xpcall",

    "coroutine",
    "debug",
    "io",
    "math",
    "os",
    "package",
    "string",
    "table",
]);

exports.generate = (libname, info, options) => {
    return `
        -- Generated

        local function startswith(s, start)
            return s:sub(1, #start) == start
        end

        local al5_ffi = {}
        local ${ libname }_lua = require "${ libname }_lua"
        local ${ libname } = ${ libname }_lua.${ libname }
        local loaded = {}

        al5_ffi.cdef = ${ libname }_lua.cdef .. [[
            ${ info.cdef.replace(/^(?: {2})+/mg, match => match.repeat(2)).split("\n").join(`\n${ " ".repeat(12) }`) }
        ]]

        al5_ffi.cglobals = [[
            struct tm {
                int tm_sec;           /* Seconds. [0-60] 1 leap second */
                int tm_min;           /* Minutes. [0-59]      */
                int tm_hour;          /* Hours.   [0-23]      */
                int tm_mday;          /* Day.     [1-31]      */
                int tm_mon;           /* Month.   [0-11]      */
                int tm_year;          /* Year - 1900.         */
                int tm_wday;          /* Day of week. [0-6]   */
                int tm_yday;          /* Days in year.[0-365] */
                int tm_isdst;         /* DST.     [-1/0/1]    */

                long int tm_gmtoff;     /* Seconds east of UTC.    */
                const char *tm_zone;    /* Timezone abbreviation.  */
            };
            typedef struct tm tm;

            struct timespec {
                time_t tv_sec;      // nombre de secondes
                long tv_nsec;       // nombre de nanosecondes
            };
            typedef struct timespec timespec;

            ${ custom_declarations.load(options).filter(decl =>
                decl[0].startsWith("C.") && decl[2].includes(`/Call=${ decl[0].slice("C.".length) }`)
            ).map(([name, return_value_type, func_modifiers, list_of_arguments ]) => {
                const c_name = name.slice("C.".length);
                const __asm__ = asm.has(c_name) ? ` asm("${ asm.get(c_name) }")` : "";

                return `${ func_modifiers.includes("/C") ? "const " : "" }${ return_value_type } ${ c_name }(${ list_of_arguments.map(([argtype, argname, , arg_modifiers]) => {
                    return `${ arg_modifiers.includes("/C") ? "const " : "" }${ argtype } ${ argname }`;
                }).join(", ") })${ __asm__ };`;
            }).flat().join(`\n${ " ".repeat(12) }`) }
        ]]

        al5_ffi.load = function(ffi, cdef)
            if ffi == nil then
                ffi = require "ffi"
            end

            if cdef == nil then
                cdef = al5_ffi.cdef
            end

            -- multiple loading returns the same module
            local module = loaded[ffi]
            if module ~= nil then
                return module
            end

            ffi.cdef(cdef)

            local clib = ffi.load(package.searchpath("${ libname }_lua", package.cpath))

            local allegro = {
                -- enums
                ${ info.decls.filter(([type]) => type.startsWith("enum ")).map(([, , , values]) => {
                    return values.map(([value]) => {
                        const name = value.slice("const ".length);
                        return `${ name } = ${ libname }.${ name },`;
                    });
                }).flat().join(`\n${ " ".repeat(16) }`) }

                -- constructors
                ${ Object.keys(info.typedefs).filter(name => !name.startsWith("unanmed_type_")).map(name => {
                    return `${ name } = ffi.typeof("${ name }"),`;
                }).join(`\n${ " ".repeat(16) }`) }

                -- functions with out parameters
                -- functions returning nilcdata as nil
                -- functions returning const char* as string
                -- functions with const char* parameters from string
                -- functions with void* parameters from string
                ${
                    info.decls.filter(([name, return_value_type, func_modifiers, list_of_arguments]) =>
                        /^\w+$/.test(name) &&
                        (
                            list_of_arguments.some(([argtype, , , arg_modifiers]) =>
                                isCharType(argtype, arg_modifiers)
                                || isOutArg(argtype, arg_modifiers)
                                || isStringType(argtype, arg_modifiers)
                                || isVoidPtrType(argtype, arg_modifiers)
                            )
                            || isStringType(return_value_type, func_modifiers)
                            || return_value_type.endsWith("*")
                        )
                    )
                    .map(([name, return_value_type, func_modifiers, list_of_arguments]) => {
                        list_of_arguments = list_of_arguments.map(decl => {
                            const [, argname] = decl;
                            if (LUA_KEYWORDS.has(argname)) {
                                decl = decl.slice();
                                decl[1] = `_${ argname }`;
                            }
                            return decl;
                        });

                        const variadic = list_of_arguments.length !== 0 && list_of_arguments.at(-1)[0] === "...";
                        const argc = list_of_arguments.length - (variadic ? 1 : 0);
                        const out_arguments = [];
                        let optionals = 0;

                        const in_args = new Array(argc).fill(false);
                        const out_args = new Array(argc).fill(false);

                        for (let j = 0; j < argc; j++) {
                            const [, , , arg_modifiers] = list_of_arguments[j];
                            const is_in_out = arg_modifiers.includes("/IO");

                            in_args[j] = is_in_out || arg_modifiers.includes("/I");
                            out_args[j] = is_in_out || arg_modifiers.includes("/O");

                            if (out_args[j]) {
                                out_arguments.push(j);
                            }

                            // has a default value
                            if (!in_args[j] && out_args[j] || list_of_arguments[j][2] !== "") {
                                optionals++;
                            }
                        }

                        // the lua api expects parameters in this order:
                        // mandatory, optional parameter, /O parameter
                        const getArgWeight = j => {
                            if (!in_args[j] && out_args[j]) {
                                return 3;
                            }

                            // has a default value
                            if (list_of_arguments[j][2] !== "") {
                                return 2;
                            }

                            // is non optional value
                            return 1;
                        };

                        const indexes = Array.from(new Array(argc).keys()).sort((a, b) => {
                            const diff = getArgWeight(a) - getArgWeight(b);
                            return diff === 0 ? a - b : diff;
                        });

                        const nfixedargs = list_of_arguments.length - optionals;

                        const args = indexes.slice(0, nfixedargs).map(j => toArgument(list_of_arguments[j]));
                        if (variadic || optionals !== 0) {
                            args.push("...");
                        }

                        const indent = " ".repeat(28);

                        const body = [];

                        if (out_arguments.length !== 0) {
                            out_arguments.sort((a, b) => {
                                const diff = getArgWeight(a) - getArgWeight(b);
                                return diff === 0 ? a - b : diff;
                            });

                            body.push(`${ body.length !== 0 ? indent : "" }local variadic_args = {n=select("#", ...), ...}\n`);

                            body.push(indent + out_arguments.map(j => list_of_arguments[j]).map(([argtype, argname], i) => `
                                local ${ argname } = ffi.new("${ argtype.slice(0, -1).trim() }[1]")
                                if variadic_args.n >= ${ i + 1 } then
                                    if variadic_args[${ i + 1 }] == nil then
                                        ${ argname } = nil
                                    else
                                        local __str__ = tostring(variadic_args[1])
                                        if startswith(__str__, "cdata<${ argtype.slice(0, -1).trim() } [?]>:") or startswith(__str__, "cdata<${ argtype.slice(0, -1).trim() } [1]>:") then
                                            ${ argname } = variadic_args[${ i + 1 }]
                                        else
                                            ${ argname }[0] = variadic_args[${ i + 1 }]
                                        end
                                    end
                                end
                            `.replace(/^ {4}/mg, "").trim()).join(`\n\n${ indent }`));

                            // new line
                            body.push("");
                        }

                        const pointer_arguments = list_of_arguments.filter(([argtype, , , arg_modifiers]) => isVoidPtrType(argtype, arg_modifiers) || isStringType(argtype, arg_modifiers));
                        if (pointer_arguments.length !== 0) {
                            body.push((body.length !== 0 ? indent : "") + pointer_arguments.map(([argtype, argname]) => `
                                ${ argname } = (function(str)
                                    if type(str) ~= "string" then return str end
                                    return ffi.new("char[?]", #str + 1, str)
                                end)(${ argname })
                            `.replace(/^ {4}/mg, "").trim()).join(`\n\n${ indent }`));

                            // new line
                            body.push("");
                        }

                        const char_arguments = list_of_arguments.filter(([argtype, , , arg_modifiers]) => isCharType(argtype, arg_modifiers));
                        if (char_arguments.length !== 0) {
                            body.push((body.length !== 0 ? indent : "") + char_arguments.map(([argtype, argname]) => `
                                ${ argname } = (function(str)
                                    if type(str) ~= "string" then return str end
                                    return string.byte(str)
                                end)(${ argname })
                            `.replace(/^ {4}/mg, "").trim()).join(`\n\n${ indent }`));

                            // new line
                            body.push("");
                        }

                        body.push(body.length !== 0 ? indent : "");
                        if (return_value_type !== "void") {
                            body[body.length - 1] += "local ret = ";
                        }
                        body[body.length - 1] += `clib.${ name }(${ list_of_arguments.map(toArgument).join(", ") })`;

                        const returns = out_arguments.map(j => list_of_arguments[j]).map(([, argname]) => `(function() if ${ argname } == nil then return nil else return ${ argname }[0] end end)()`);

                        if (return_value_type !== "void") {
                            returns.unshift("ret");

                            if (isStringType(return_value_type, func_modifiers)) {
                                body.push(`${ indent }if ret ~= nil then ret = ffi.string(ret) else ret = nil end -- return nilcdata as nil`);
                            } else if (return_value_type.endsWith("*")) {
                                body.push(`${ indent }if ret == nil then ret = nil end -- return nilcdata as nil`);
                            }
                        }

                        if (returns.length !== 0) {
                            body.push(`${ indent }return ${ returns.join(", ") }`);
                        }

                        return `${ name } = function(${ args.join(", ") })
                            ${ body.join("\n") }
                        end,`.replace(/^ {8}/mg, "").trim();
                    })
                    .join(`\n\n${ " ".repeat(16) }`)
                }

                -- custom declarations
                ${ custom_declarations.load(options).filter(decl => decl[0] === `${ libname }.` && decl[2].includes("/Properties")).map(([, , , properties]) => {
                    return properties.filter(([, , , modifiers]) => modifiers.includes("/C")).map(([, name]) => {
                        return `${ name } = ${ libname }.${ name },`;
                    });
                }).flat().join(`\n${ " ".repeat(16) }`) }

                -- macro functions
                al_init = ${ libname }.al_init,
                al_malloc = function(n)
                    local info = debug.getinfo(1, 'Sln')
                    return clib.al_malloc_with_context(n, info.currentline, info.source, info.name)
                end,
                al_calloc = function(c, n)
                    local info = debug.getinfo(1, 'Sln')
                    return clib.al_calloc_with_context(c, n, info.currentline, info.source, info.name)
                end,
                al_realloc = function(p, n)
                    local info = debug.getinfo(1, 'Sln')
                    return clib.al_realloc_with_context(p, n, info.currentline, info.source, info.name)
                end,
                al_free = function(p)
                    local info = debug.getinfo(1, 'Sln')
                    clib.al_free_with_context(p, info.currentline, info.source, info.name)
                end,
            }

            ${ al5_functions.split("\n").join(`\n${ " ".repeat(12) }`) }

            setmetatable(allegro, {
                __index = clib,
            })

            -- ================================
            -- include/allegros/alcompat.h
            -- ================================
            ${ [
                ["ALLEGRO_DEST_COLOR", "ALLEGRO_DST_COLOR"],
                ["ALLEGRO_INVERSE_DEST_COLOR", "ALLEGRO_INVERSE_DST_COLOR"],
                ["al_convert_memory_bitmaps", "al_convert_bitmaps"],
                ["al_get_time", "al_current_time"],
                ["al_is_event_queue_empty", "al_event_queue_is_empty"],
                ["al_set_display_flag", "al_toggle_display_flag"],
            ].map(([target, alias]) => `allegro.${ alias } = allegro.${ target }`).join(`\n${ " ".repeat(12) }`) }
            -- ================================

            loaded[ffi] = allegro
            return allegro
        end

        return setmetatable(al5_ffi, {
            __call = function(exports, ...)
                return exports.load(...)
            end
        })
    `.replace(/^ {8}/mg, "").trim().replace(/[^\S\r\n]+$/mg, "");
};
