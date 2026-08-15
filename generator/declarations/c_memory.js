module.exports = [
    ["C.malloc", "void*", ["/Call=malloc"], [
        ["size_t", "n", "", []],
    ], "", ""],

    ["C.calloc", "void*", ["/Call=calloc"], [
        ["size_t", "num", "", []],
        ["size_t", "size", "", []],
    ], "", ""],

    ["C.realloc", "void*", ["/Call=realloc"], [
        ["void*", "ptr", "", []],
        ["size_t", "new_size", "", []],
    ], "", ""],

    ["C.free", "void", ["/Call=free"], [
        ["void*", "ptr", "", []],
    ], "", ""],

    ["C.memcmp", "int", ["/Call=memcmp"], [
        ["void*", "lhs", "", ["/C"]],
        ["void*", "rhs", "", ["/C"]],
        ["size_t", "count", "", []],
    ], "", ""],

    ["C.memset", "void*", ["/Call=memset"], [
        ["void*", "dest", "", []],
        ["int", "ch", "", []],
        ["size_t", "count", "", []],
    ], "", ""],

    ["C.memcpy", "void*", ["/Call=memcpy"], [
        ["void*", "dest", "", []],
        ["void*", "src", "", ["/C"]],
        ["size_t", "count", "", []],
    ], "", ""],

    ["C.memmove", "void*", ["/Call=memmove"], [
        ["void*", "dest", "", []],
        ["void*", "src", "", ["/C"]],
        ["size_t", "count", "", []],
    ], "", ""],

    ["C.intptr_t", "intptr_t", ["/Call=reinterpret_cast<intptr_t>"], [
        ["void*", "ptr", "", []],
    ], "", ""],

    ["C.voidptr_t", "void*", ["/Call=reinterpret_cast<void*>"], [
        ["intptr_t", "ptr", "", []],
    ], "", ""],
];
