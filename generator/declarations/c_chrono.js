module.exports = [
    ["struct tm", "", ["/Simple", "/DC"], [
        ["int", "tm_sec", "", ["/RW"]],
        ["int", "tm_min", "", ["/RW"]],
        ["int", "tm_hour", "", ["/RW"]],
        ["int", "tm_mday", "", ["/RW"]],
        ["int", "tm_mon", "", ["/RW"]],
        ["int", "tm_year", "", ["/RW"]],
        ["int", "tm_wday", "", ["/RW"]],
        ["int", "tm_yday", "", ["/RW"]],
        ["int", "tm_isdst", "", ["/RW"]],
    ], "", ""],

    ["struct timespec", "", ["/Simple", "/DC"], [
        ["time_t", "tv_sec", "", ["/RW"]],
        ["long", "tv_nsec", "", ["/RW"]],
    ], "", ""],

    ["C.difftime", "double", ["/Call=difftime"], [
        ["time_t", "end", "", []],
        ["time_t", "beg", "", []],
    ], "", ""],

    ["C.time", "time_t", ["/Call=time"], [
        ["time_t*", "arg", "", []],
    ], "", ""],

    ["C.clock", "clock_t", ["/Call=clock"], [
        // No arguments
    ], "", ""],

    ["C.timespec_get", "int", ["/Call=timespec_get"], [
        ["timespec *", "ts", "", ["/IO"]],
        ["int", "base", "", []],
    ], "", ""],

    ["C.asctime", "char*", ["/Call=asctime"], [
        ["tm*", "time_ptr", "", ["/C"]],
    ], "", ""],

    // Need #define __STDC_WANT_LIB_EXT1__ 1 and #ifdef __STDC_LIB_EXT1__
    // ["C.asctime_s", "errno_t", ["/Call=asctime_s"], [
    //     ["char*", "buf", "", []],
    //     ["size_t", "bufsz", "", []],
    //     ["tm*", "time_ptr", "", ["/C"]],
    // ], "", ""],

    ["C.ctime", "char*", ["/Call=ctime"], [
        ["time_t*", "timer", "", ["/C", "/I"]],
    ], "", ""],

    // Need #define __STDC_WANT_LIB_EXT1__ 1 and #ifdef __STDC_LIB_EXT1__
    // ["C.ctime_s", "errno_t", ["/Call=ctime_s"], [
    //     ["char*", "buf", "", []],
    //     ["size_t", "bufsz", "", []],
    //     ["time_t*", "timer", "", ["/C", "/I"]],
    // ], "", ""],

    ["C.strftime", "size_t", ["/Call=strftime"], [
        ["char*", "str", "", []],
        ["size_t", "count", "", []],
        ["char*", "format", "", ["/C"]],
        ["tm*", "tp", "", ["/C"]],
    ], "", ""],

    ["C.gmtime", "char*", ["/Call=gmtime"], [
        ["time_t*", "timer", "", ["/C", "/I"]],
    ], "", ""],

    // Need #define __STDC_WANT_LIB_EXT1__ 1 and #ifdef __STDC_LIB_EXT1__
    // ["C.gmtime_s", "tm*", ["/Call=gmtime_s"], [
    //     ["time_t*", "timer", "", ["/C", "/I"]],
    //     ["tm*", "buf", "", ["/C"]],
    // ], "", ""],

    ["C.localtime", "tm*", ["/Call=localtime"], [
        ["time_t*", "timer", "", ["/C", "/I"]],
    ], "", ""],

    // Need #define __STDC_WANT_LIB_EXT1__ 1 and #ifdef __STDC_LIB_EXT1__
    // ["C.localtime_s", "tm*", ["/Call=localtime_s"], [
    //     ["time_t*", "timer", "", ["/C", "/I"]],
    //     ["tm*", "buf", "", ["/C"]],
    // ], "", ""],

    ["C.mktime", "time_t", ["/Call=mktime"], [
        ["tm*", "time", "", []],
    ], "", ""],

    ["C.", "", ["/Properties"], [
        ["clock_t", "CLOCKS_PER_SEC", "", ["/RExpr=CLOCKS_PER_SEC", "/C"]],
        ["int", "TIME_UTC", "", ["/RExpr=TIME_UTC", "/C"]],
    ], "", ""],
];
