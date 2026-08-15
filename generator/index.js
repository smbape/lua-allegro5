/* eslint-disable no-magic-numbers */

const fs = require("node:fs");
const fsPromises = require("node:fs/promises");
const sysPath = require("node:path");
const { spawn } = require("node:child_process");
const os = require("node:os");
const process = require("node:process");

const { mkdirp } = require("mkdirp");
const waterfall = require("async/waterfall");
const { explore } = require("fs-explorer");

const spawnExec = (cmd, args, options, next) => {
    options = Object.assign({}, options);

    // https://nodejs.org/docs/latest-v18.x/api/child_process.html#spawning-bat-and-cmd-files-on-windows
    if (os.platform() === "win32" && (cmd.endsWith(".bat") || cmd.endsWith(".cmd"))) {
        if (cmd.includes(" ")) {
            cmd = `"${ cmd }"`;
        }
        options.shell = true;
    }

    const {stdio} = options;

    if (stdio === "tee") {
        options.stdio = ["inherit", "pipe", "pipe"];
    }

    const stdout = Object.assign([], {
        nread: 0
    });

    const stderr = Object.assign([], {
        nread: 0
    });

    console.log(cmd, `'${ args.join("' '") }'`);

    let err = false;

    const child = spawn(cmd, args, options);

    child.on("error", _err => {
        err = true;
        next(_err);
    });

    child.on("close", code => {
        if (err) {
            return;
        }

        if (stdio === "tee" || stdio === "pipe" || Array.isArray(stdio) && (stdio[1] === "pipe" || stdio[2] === "pipe")) {
            next(code, Buffer.concat(stdout, stdout.nread), Buffer.concat(stderr, stderr.nread));
        } else {
            next(code);
        }
    });

    if (stdio === "tee" || stdio === "pipe" || Array.isArray(stdio) && stdio[1] === "pipe") {
        child.stdout.on("data", chunk => {
            stdout.push(chunk);
            stdout.nread += chunk.length;
            if (stdio === "tee") {
                process.stdout.write(chunk);
            }
        });
    }

    if (stdio === "tee" || stdio === "pipe" || Array.isArray(stdio) && stdio[2] === "pipe") {
        child.stderr.on("data", chunk => {
            stderr.push(chunk);
            stderr.nread += chunk.length;
            process.stderr.write(chunk);
        });
    }
};

const Python3_EXECUTABLE = process.env.Python3_EXECUTABLE ? process.env.Python3_EXECUTABLE : "python";

const c_globals = new Set([
    // time
    "tm",
    "timespec",
]);

const alias = require("./alias");

const {
    ALIASES,
    CUSTOM_CLASSES,
} = require("./constants");

const primitiveTypes = new Set([
    "char",
    "short",
    "int",
    "long",
    "float",
    "double",
    "signed",
    "unsigned",
    "bool",

    // https://en.cppreference.com/w/cpp/language/types
    "signed char",
    "unsigned char",
    "short int",
    "signed short",
    "signed short int",
    "unsigned short",
    "unsigned short int",
    "short unsigned int",
    "signed int",
    "unsigned int",
    "long int",
    "signed long",
    "signed long int",
    "unsigned long",
    "unsigned long int",
    "long unsigned int",
    "long long",
    "long long int",
    "signed long long",
    "signed long long int",
    "unsigned long long",
    "unsigned long long int",
    "long long unsigned int",
    "long double"
]);

const getOptions = output => {
    const options = {
        APP_NAME: "Allegro5",
        language: "lua",
        shared_ptr: "std::shared_ptr",
        make_shared: "std::make_shared",
        Any: "::LUA_MODULE_NAME::Object",
        AnyObject: "::LUA_MODULE_NAME::Object",
        largc: "__argc__",
        vargc: "__vargc__",
        cname: "new",

        isCaseSensitive: true,
        hasIsInstanceSupport: true, // do not generate reflection methods and properties
        hasInheritanceSupport: true, // do not duplicate parent methods
        hasCopyConstructorSupport: true, // copy constructors for simple struct

        // used to lookup classes
        namespaces: new Set([]),

        other_namespaces: new Set(),

        // used to reduce class name length
        remove_namespaces: new Set([
            "allegro5",
            "std",
        ]),

        self: "*self",
        self_get: (name = null) => {
            return name ? `self->${ name }` : "self";
        },

        build: new Set(),
        notest: new Set(),
        skip: new Set(),

        output: sysPath.join(output, "generated"),
        generated: new Map(),

        onClass: (processor, coclass, opts) => {
            // Nothing to do
        },

        onCoClass: (processor, coclass, opts) => {
            // Nothing to do
        },

        progids: {
            has: id => id.length === 0 || id === "this" || id.startsWith("ALLEGRO_") || id.startsWith("al_") || c_globals.has(id),
            get: id => {
                if (id.length === 0) {
                    return "allegro5";
                }

                if (id === "this") {
                    return "";
                }

                if (c_globals.has(id)) {
                    return `C.${ id }`;
                }

                return `allegro5.${ id }`;
            },
        },

        variadic: (return_value_type, callee, expr, offset, callargs) => {
            return `ffi_call_variadic(L, ${ offset }, ${ callee }, ${ expr })`;
        },

        makeDependent(processor, cpptype, coclass, opts) {
           if (cpptype.startsWith("expand_all_extents_t<") && cpptype.endsWith(">")) {
                const atype = cpptype.slice("expand_all_extents_t<".length, -">".length);
                let pos = atype.indexOf("[");
                let typename = alias.removeConstQualifiers(atype.slice(0, pos).trim());
                if (ALIASES.has(typename)) {
                    typename = alias.getAlias(ALIASES.get(typename));
                }
                let open = 1;
                let pointers = 0;

                for (pos++; pos < atype.length; pos++) {
                    if (atype[pos] === "[") {
                        open++;
                    } else if (atype[pos] === "]") {
                        open--;
                        if (open === 0) {
                            pointers++;
                        }
                    }
                }

                for (let i = 0; i < pointers; i++) {
                    processor.add_vector(`std::vector<${ typename + "*".repeat(i) }>`, coclass, opts);
                }
            } else if (cpptype.endsWith("*")) {
                let pointers = "*".length;
                for (let i = cpptype.length - 1 - "*".length; i >= 0; i--) {
                    if (cpptype[i] !== "*") {
                        break;
                    }
                    pointers++;
                }

                let typename = alias.removeConstQualifiers(cpptype.slice(0, -pointers).trim());
                if (ALIASES.has(typename)) {
                    typename = alias.getAlias(ALIASES.get(typename));
                }

                const start = primitiveTypes.has(typename) || processor.classes.has(typename) && processor.classes.get(typename).is_simple ? 0 : 1;

                for (let i = start; i < pointers; i++) {
                    processor.add_vector(`std::vector<${ typename + "*".repeat(i) }>`, coclass, opts);
                }
            }
        },

        getDocCppType: (processor, doctype, coclass, opts) => {
            if (doctype.startsWith("expand_all_extents_t<")) {
                return doctype.slice("expand_all_extents_t<".length, -">".length);
            }

            if (doctype.startsWith("CFunctionInvoker<")) {
                const rstart = "CFunctionInvoker<".length;
                let rend = rstart + 1;
                let open = 0;
                for (; open !== 1 && rend < doctype.length; rend++) {
                    if (doctype[rend] === "(") {
                        open++;
                    } else if (doctype[rend] === ")") {
                        open--;
                    }
                }
                return `${ doctype.slice("CFunctionInvoker<".length, rend - 2) }(*) ${ doctype.slice(rend - 1, -">::Pointer".length) }`;
            }

            return doctype;
        },

        getDefitionType: (processor, definitiontype, coclass, opts) => {
            if (definitiontype.startsWith("expand_all_extents_t<")) {
                return LuaGenerator.getDefitionType(processor, definitiontype.slice("expand_all_extents_t<".length, -">".length), coclass, opts);
            }

            if (definitiontype.startsWith("CFunctionInvoker<")) {
                // TODO get lua function signature from c function
                return "function";
            }

            return definitiontype;
        },

        definitions: [`
            ---@class bit : table
            local bit = {}
            allegro5_lua.bit = bit

            ---Normalizes a number to the numeric range for bit operations and returns it.
            ---@param x integer
            ---@return integer
            function bit.tobit(x) end

            ---Converts its first argument to a hex string.
            ---@param x integer
            ---@param n? integer
            ---@return string
            function bit.tohex(x, n) end

            ---Returns the bitwise not of its argument.
            ---@param x integer
            ---@return integer
            function bit.bnot(x) end

            ---Returns the bitwise <b>or</b> of all of its arguments.
            ---@param x1 integer
            ---@param ... integer
            ---@return integer
            function bit.bor(x1, ...) end

            ---Returns the bitwise <b>and</b> of all of its arguments.
            ---@param x1 integer
            ---@param ... integer
            ---@return integer
            function bit.band(x1, ...) end

            ---Returns the bitwise <b>xor</b> of all of its arguments.
            ---@param x1 integer
            ---@param ... integer
            ---@return integer
            function bit.bxor(x1, ...) end

            ---Returns the bitwise <b>logical left-shift</b> of its first argument by the number of bits given by the second argument. 
            ---@param x integer
            ---@param n integer
            ---@return integer
            function bit.lshift(x, n) end

            ---Returns the bitwise <b>logical right-shift</b> of its first argument by the number of bits given by the second argument. 
            ---@param x integer
            ---@param n integer
            ---@return integer
            function bit.rshift(x, n) end

            ---Returns the bitwise <b>arithmetic right-shift</b> of its first argument by the number of bits given by the second argument. 
            ---@param x integer
            ---@param n integer
            ---@return integer
            function bit.arshift(x, n) end

            ---Returns the bitwise <b>left rotation</b> of its first argument by the number of bits given by the second argument.
            ---@param x integer
            ---@param n integer
            ---@return integer
            function bit.rol(x, n) end

            ---Returns the bitwise <b>right rotation</b> of its first argument by the number of bits given by the second argument.
            ---@param x integer
            ---@param n integer
            ---@return integer
            function bit.ror(x, n) end

            ---Swaps the bytes of its argument and returns it.
            ---@param x integer
            ---@return integer
            function bit.bswap(x) end


            ---@class allegro5_lua.string : table
            allegro5_lua.string = {}

            ---Return a copy of the string with the leading and trailing spaces removed.
            ---@param chars string
            ---@param ltrim? boolean remove leading spaces. Default = true
            ---@param rtrim? boolean remove trailing spaces. Default = true
            ---@return string
            function allegro5_lua.string.trim(chars, ltrim, rtrim) end

            ---Returns a table as keyword arguments.
            ---@param tbl? table
            ---@return table
            function allegro5_lua.kwargs(tbl) end

            ---@class math : table
            local math = {}
            allegro5_lua.math = math

            ---Rounds a number to the given number of decimal places.
            ---@param num number
            ---@param decimals? integer
            ---@return number
            function math.round(num, decimals) end

            ---Similar to math.floor.
            ---@param num number
            ---@return integer
            function math.int(num) end

        `.replace(/^ {12}/mg, "").trim(), ""],
    };

    const argv = process.argv.slice(2);
    const flags_true = ["hdr", "impl", "save"];
    const flags_false = ["test"];

    for (const opt of flags_true) {
        options[opt] = !argv.includes(`--no-${ opt }`);
    }

    for (const opt of flags_false) {
        options[opt] = argv.includes(`--${ opt }`);
    }

    for (let i = 0; i < argv.length; i++) {
        const opt = argv[i];

        if (opt.startsWith("--no-") && flags_true.includes(opt.slice("--no-".length))) {
            continue;
        }

        if (opt.startsWith("--") && flags_false.includes(opt.slice("--".length))) {
            continue;
        }

        if (opt.startsWith("--no-test=")) {
            for (const fqn of opt.slice("--no-test=".length).split(/[ ,]/)) {
                options.notest.add(fqn);
            }
            continue;
        }

        if (opt.startsWith("--build=")) {
            for (const fqn of opt.slice("--build=".length).split(/[ ,]/)) {
                options.build.add(fqn);
            }
            continue;
        }

        if (opt.startsWith("--skip=")) {
            for (const fqn of opt.slice("--skip=".length).split(/[ ,]/)) {
                options.skip.add(fqn);
            }
            continue;
        }

        if (opt.startsWith("-D")) {
            const [key, value] = opt.slice("-D".length).split("=");
            options[key] = typeof value === "undefined" ? true : value;
            continue;
        }

        throw new Error(`Unknown option ${ opt }`);
    }

    return options;
};

const {findFile} = require("./FileUtils");
const custom_declarations = require("./custom_declarations");
const DeclProcessor = require("./DeclProcessor");
const LuaGenerator = require("./LuaGenerator");
const LuaJITFFIGenerator = require("./LuaJITFFIGenerator");

const PROJECT_DIR = sysPath.dirname(__dirname);
const SRC_DIR = sysPath.join(PROJECT_DIR, "src");

const findSourceDir = name => {
    const platform = os.platform() === "win32" ? (/cygwin/.test(process.env.HOME) ? "Cygwin" : "x64") : "*-GCC";

    const hints = [
        `out/build/${ platform }-*`,
        "build.luarocks",
    ];

    if (process.env.CMAKE_BINARY_DIR) {
        hints.unshift(process.env.CMAKE_BINARY_DIR);
    }

    for (const hint of hints) {
        const file = findFile(`${ hint }/${ name }`, PROJECT_DIR);
        if (file) {
            return file;
        }
    }

    return null;
};

const opencv_SOURCE_DIR = findSourceDir("opencv/opencv-src");

const src2 = sysPath.resolve(opencv_SOURCE_DIR, "modules/python/src2");

const hdr_parser = fs.readFileSync(sysPath.join(src2, "hdr_parser.py")).toString();
const hdr_parser_start = hdr_parser.indexOf("]") + 1;
const hdr_parser_end = hdr_parser.indexOf("if __name__ == '__main__':", hdr_parser);

const options = getOptions(PROJECT_DIR);
options.proto = LuaGenerator.proto;

options.generated.set(sysPath.join(options.output, "bit_string.lua.inc"), true);
options.generated.set(sysPath.join(options.output, "version_string.inc"), true);

const getExtractorType = type => {
    // if (type.includes("(*)") && type.endsWith(")")) {
    //     return `CFunctionInvoker<${ type }>::Pointer`;
    // }

    if (type.endsWith("]")) {
        return `expand_all_extents_t<${ type }>`;
    }

    return type;
};

waterfall([
    next => {
        mkdirp(options.output).then(performed => {
            next();
        }, next);
    },

    next => {
        const srcfiles = [];

        explore(SRC_DIR, async (path, stats, next) => {
            const relpath = path.slice(SRC_DIR.length + 1);
            const parts = relpath.split(".");
            const extname = parts.length === 0 ? "" : `.${ parts[parts.length - 1] }`;
            const extnames = parts.length === 0 ? "" : `.${ parts.slice(-2).join(".") }`;
            const isheader = [".h", ".hh", ".hpp", ".hxx"].includes(extname);

            const content = await fsPromises.readFile(path);

            if (isheader && ![".impl.h", ".impl.hh", ".impl.hpp", ".impl.hxx"].includes(extnames) && (content.includes("CV_EXPORTS") || /^binding[\\/]/.test(relpath))) {
                srcfiles.push(path);
            }

            next();
        }, {followSymlink: true}, err => {
            const generated_include = srcfiles.map(path => `#include "${ path.slice(SRC_DIR.length + 1).replace("\\", "/") }"`);
            next(err, srcfiles, generated_include);
        });
    },

    (srcfiles, generated_include, next) => {
        const alplatf = findSourceDir("allegro5/allegro5-src/include/allegro5/platform/alplatf.h.cmake");
        fs.readFile(alplatf, (err, buffer) => {
            next(err, srcfiles, generated_include, buffer);
        });
    },

    (srcfiles, generated_include, alplatf, next) => {
        const config = new Map();

        const definesReg = /^#cmakedefine (?<cfg>\w+)$/mg;

        let match;
        while (match = definesReg.exec(alplatf)) { // eslint-disable-line no-cond-assign
            const {cfg} = match.groups;
            config.set(cfg, false);
        }

        next(null, srcfiles, generated_include, config);
    },

    (srcfiles, generated_include, config, next) => {
        const alplatf = findSourceDir("allegro5/allegro5-build/include/allegro5/platform/alplatf.h");
        fs.readFile(alplatf, (err, buffer) => {
            next(err, srcfiles, generated_include, config, buffer);
        });
    },

    (srcfiles, generated_include, config, alplatf, next) => {
        const properties = [];

        const definesReg = /^#define (?<cfg>\w+)$/mg;

        let match;
        while (match = definesReg.exec(alplatf)) { // eslint-disable-line no-cond-assign
            const {cfg} = match.groups;
            config.set(cfg, true);
        }

        for (const [cfg, value] of config.entries()) {
            properties.push(["bool", cfg, "", [`/RExpr=${ value }`, "/C"]]);
        }

        custom_declarations.push(["allegro5.", "", ["/Properties"], properties, "", ""]);
        next(null, srcfiles, generated_include);
    },

    (srcfiles, generated_include, next) => {
        const cdefs = findSourceDir("allegro5_lua/luajit-2.1/cdefs/cdefs.txt");
        fs.readFile(cdefs, (err, buffer) => {
            next(err, srcfiles, generated_include, buffer);
        });
    },

    (srcfiles, generated_include, cdefs, next) => {
        const typedefsReg = /^typedef (?<definition>.+) (?<typedef>\w+);$/mg;

        let match;
        while (match = typedefsReg.exec(cdefs)) { // eslint-disable-line no-cond-assign
            const {definition, typedef} = match.groups;
            ALIASES.set(typedef, definition.replace(/^struct\s+/, ""));
        }

        const properties = [];

        const vectors = [];

        for (const type of [
            "int8_t",
            "uint8_t",
            "int16_t",
            "uint16_t",
            "int32_t",
            "uint32_t",
            "int64_t",
            "uint64_t",
            "ALLEGRO_USTR_INFO",
            "ALLEGRO_USTR",
        ]) {
            const vector = `std::vector<${ type }>`;

            if (ALIASES.has(type)) {
                const realvector = `std::vector<${ alias.getAlias(ALIASES.get(type)) }>`;
                const definitionTypeDef = alias.getTypeDef(realvector, options);
                const aliasTypeDef = alias.getTypeDef(vector, options);
                properties.push([definitionTypeDef, aliasTypeDef, "", ["/R", "=this", "/S"]]);
                vectors.push(realvector);
            } else {
                vectors.push(vector);
            }
        }

        custom_declarations.push(["this.", "", ["/Properties"], properties, "", ""]);
        options.vectors = vectors;

        fs.readFile(sysPath.join(__dirname, "c_parser", "c_protos.h"), (err, buffer) => {
            next(err, srcfiles, generated_include, buffer);
        });
    },

    (srcfiles, generated_include, c_protos, next) => {
        generated_include.unshift(
            ...c_protos.toString().trim().split(/\r?\n/),
        );

        generated_include = Array.from(new Set(generated_include));

        spawnExec(Python3_EXECUTABLE, ["c_parser/cdecl_allegro5.py"], {
            stdio: ["inherit", "pipe", "inherit"],
            cwd: __dirname
        }, (err, _stdout, _stderr) => {
            next(err, srcfiles, generated_include, _stdout, _stderr);
        });
    },

    (srcfiles, generated_include, _stdout, _stderr, next) => {
        const allegro5 = JSON.parse(_stdout.toString());

        for (const name of Object.keys(allegro5.functions)) {
            allegro5.aliases[name] = "function";
        }

        for (let i = allegro5.decls.length - 1; i >= 0; i--) {
            const decl = allegro5.decls[i];
            const [name] = decl;
            const [/* name */, /* return_value_type */, func_modifiers, /* list_of_arguments */] = decl;

            if (name === "al_cstr") {
                func_modifiers.push("/WrapAs=const_cast<char*>");
            } else if (name === "al_rest" || name.startsWith("al_wait_") || name.startsWith("al_") && name.endsWith("_callback")) {
                // Release the global interpreter lock before waiting
                // Thus, allowing any callback to be called
                func_modifiers.push("/GU");
            }
        }

        options.generated.set(sysPath.join(options.output, "al5_ffi.lua"), LuaJITFFIGenerator.generate("allegro5", allegro5, options));

        const al5_functions = fs.readFileSync(sysPath.resolve(__dirname, "../allegro5_lua/al5_functions.lua")).toString().trim();
        options.generated.set(sysPath.join(options.output, "al5_optimize.lua"), `
            local function load(allegro5_lua, allegro, bit)
                ${ al5_functions.split("\n").join(`\n${ " ".repeat(16) }`) }
            end

            return setmetatable({}, {
                __call = function(exports, ...)
                    return load(...)
                end
            })
        `.replace(/^ {12}/mg, "").trim().replace(/[^\S\n]+$/mg, ""));

        allegro5.structs_ffi_types["void *"] = false;

        options.generated.set(sysPath.join(options.output, "lua_bridge_ffi_types.hdr.hpp"), `
            #pragma once

            ${ [
                ...generated_include.filter(inc => inc.startsWith("#include <allegro5/")),
                "#include <lua_bridge.hdr.hpp>",
                "#include <lua_generated_include.hpp>",
            ].join(`\n${ " ".repeat(12) }`) }

            namespace LUA_MODULE_NAME {
                ${ Object.values(allegro5.structs_ffi_types).filter(value => Array.isArray(value)).map(([declaration]) => declaration).join("\n\n").split("\n").join(`\n${ " ".repeat(16) }`) }
            }
        `.replace(/^ {12}/mg, "").trim().replace(/[^\S\n]+$/mg, ""));

        options.generated.set(sysPath.join(options.output, "lua_bridge_ffi_types.cpp"), `
            #include <lua_bridge_ffi_types.hdr.hpp>

            namespace {
                using namespace LUA_MODULE_NAME;

                template<typename T>
                struct ffi_arg_pusher {
                    static void push(lua_State* L, void* arg) {
                        lua_push(L, *static_cast<T*>(arg));
                    }
                };

                template<std::size_t N>
                struct ffi_arg_pusher<char[N]> {
                    static void push(lua_State* L, void* arg) {
                        lua_pushlstring(L, *static_cast<char(*)[N]>(arg), N);
                    }
                };

                template<typename T>
                void ffi_arg_copy(void** dst, void* src) {
                    *dst = malloc(sizeof(T));
                    memcpy(*dst, src, sizeof(T));
                }

                template<typename T>
                void ffi_arg_destroy(void* ptr) {
                    if (ptr) {
                        free(ptr);
                    }
                }

                template<typename T, typename V>
                void* ffi_arg_extract(lua_State* L, int index, bool& is_valid) {
                    auto value_holder = lua_to(L, index, static_cast<T*>(nullptr), is_valid);
                    if (!is_valid) {
                        return nullptr;
                    }

                    decltype(auto) value = extract_holder(value_holder, static_cast<T*>(nullptr));
                    void* dst = nullptr;
                    ffi_arg_copy<V>(&dst, &static_cast<V&>(value));
                    return dst;
                }
            }

            namespace LUA_MODULE_NAME {
                ${ Object.values(allegro5.structs_ffi_types).filter(value => Array.isArray(value)).map(([, implementation]) => implementation).join("\n\n").split("\n").join(`\n${ " ".repeat(16) }`) }

                void register_extractors() {
                    ${ Object.keys(allegro5.structs_ffi_types)
                        .filter(type => !type.includes("(*)") || !type.endsWith(")"))
                        .map(type => `
                            register_extractor("${ type }", FFIArgExtractor{
                                .extract = ffi_arg_extract<${ getExtractorType(type) }, ${ type }>,
                                .push = ffi_arg_pusher<${ type }>::push,
                                .copy = ffi_arg_copy<${ type }>,
                                .destroy = ffi_arg_destroy<${ type }>,
                                .ffi_type_ptr = FFITypeTraits<${ type }>::ffi_type_ptr()
                            });
                        `.replace(/^ {8}/mg, "").trim())
                        .join(`\n\n${ " ".repeat(20) }`) }
                }
            }
        `.replace(/^ {12}/mg, "").trim().replace(/[^\S\n]+$/mg, ""));

        next(null, srcfiles, generated_include, allegro5);
    },

    (srcfiles, generated_include, allegro5, next) => {
        const buffers = [];
        let nlen = 0;
        const child = spawn(Python3_EXECUTABLE, []);

        child.stderr.on("data", chunk => {
            process.stderr.write(chunk);
        });

        child.on("close", code => {
            if (code !== 0) {
                console.log(`python process exited with code ${ code }`);
                process.exit(code);
            }

            const buffer = Buffer.concat(buffers, nlen);

            const configuration = JSON.parse(buffer.toString());

            configuration.decls.push(...allegro5.decls);
            configuration.typedefs = new Map(Object.entries(allegro5.typedefs));
            options.daliases = new Map(Object.entries(allegro5.aliases));
            options.daliases.set("sig_atomic_t", "integer");

            configuration.decls.push(...custom_declarations.load(options));
            configuration.generated_include = generated_include;

            for (const [name, modifiers] of CUSTOM_CLASSES) {
                configuration.decls.push([`class ${ name }`, "", modifiers, [], "", ""]);
            }

            configuration.namespaces.push(...options.namespaces);
            configuration.namespaces.push(...options.other_namespaces);

            const processor = new DeclProcessor(options);
            processor.process(configuration, options);

            next(null, processor, configuration);
        });

        child.stderr.on("data", chunk => {
            process.stderr.write(chunk);
        });

        child.stdout.on("data", chunk => {
            buffers.push(chunk);
            nlen += chunk.length;
        });

        const code = `
            import io, json, os, re, string, sys

            ${ hdr_parser
                .slice(hdr_parser_start, hdr_parser_end)
                .split("\n")
                .join(`\n${ " ".repeat(12) }`) }

            srcfiles = []
            ${ srcfiles.map(file => `srcfiles.append(${ JSON.stringify(file) })`).join(`\n${ " ".repeat(12) }`) }

            parser = CppHeaderParser(
                generate_umat_decls=True,
                generate_gpumat_decls=True,
                preprocessor_definitions={
                    "LUA_VERSION_NUM": 504,
                }
            )
            all_decls = []
            for hdr in srcfiles:
                decls = parser.parse(hdr)
                if len(decls) == 0 or hdr.find('/python/') != -1:
                    continue

                all_decls += decls

            # parser.print_decls(all_decls)
            print(json.dumps({"decls": all_decls, "namespaces": sorted(parser.namespaces)}, indent=4))
        `.trim().replace(/^ {12}/mg, "");

        child.stdin.write(code);
        child.stdin.end();

        // fs.writeFileSync(sysPath.join(PROJECT_DIR, "gen.py"), code.replace("# parser.print_decls", "parser.print_decls").replace("print(json.dumps", "# print(json.dumps"));
    },

    (processor, configuration, next) => {
        const generator = new LuaGenerator();
        generator.generate(processor, configuration, options, next);
    },
], err => {
    if (err) {
        throw err;
    }
    console.log(`Build files have been written to: ${ options.output }`);
});
