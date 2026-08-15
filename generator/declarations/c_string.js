module.exports = [
    ["std.string", "std::string", [], [
        ["void*", "ptr", "", ["/Cast=static_cast<char*>"]],
    ], "", ""],

    ["std.string", "std::string", [], [
        ["void*", "ptr", "", ["/Cast=static_cast<char*>"]],
        ["size_t", "len", "", []],
    ], "", ""],

    ["C.strcmp", "int", ["/Call=strcmp"], [
        ["char*", "lhs", "", ["/C"]],
        ["char*", "rhs", "", ["/C"]],
    ], "", ""],

    ["C.strncmp", "int", ["/Call=strncmp"], [
        ["char*", "lhs", "", ["/C"]],
        ["char*", "rhs", "", ["/C"]],
        ["size_t", "count", "", []],
    ], "", ""],

    ["C.strcpy", "char*", ["/Call=strcpy"], [
        ["char*", "dest", "", []],
        ["char*", "src", "", ["/C"]],
    ], "", ""],
];
