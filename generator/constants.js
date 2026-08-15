exports.SIMPLE_ARGTYPE_DEFAULTS = new Map([
    ["bool", "0"],
    ["size_t", "0"],
    ["std::size_t", "0"],
    ["SSIZE_T", "0"],
    ["ssize_t", "0"],
    ["int", "0"],
    ["float", "0.f"],
    ["double", "0"],

    ["int8", "0"],
    ["int8_t", "0"],
    ["int16", "0"],
    ["int16_t", "0"],
    ["int32", "0"],
    ["int32_t", "0"],
    ["int64", "0"],
    ["int64_t", "0"],

    ["uint8", "0"],
    ["uint8_t", "0"],
    ["uint16", "0"],
    ["uint16_t", "0"],
    ["uint32", "0"],
    ["uint32_t", "0"],
    ["uint64", "0"],
    ["uint64_t", "0"],
]);

exports.IDL_TYPES = new Map([]);

exports.CPP_TYPES = new Map([]);

exports.ALIASES = new Map([
    ["LUA_MODULE_NAME", "allegro5_lua"],
    ["c_string", "char*"],
    ["c_stc_string", "char**"],
    ["signed char", "char"],
    // ["_Bool", "bool"],
]);

exports.CLASS_PTR = new Set([]);

exports.PTR = new Set([
    "void*",
    "uchar*",
]);

exports.CUSTOM_CLASSES = [
    ["ALLEGRO_USER_EVENT_DESCRIPTOR", []], // Missing forward definition
];

exports.TEMPLATED_TYPES = new Set([]);

exports.IGNORED_CLASSES = new Set([
    "ALLEGRO_OGL_EXT_API",
]);
