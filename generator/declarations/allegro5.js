module.exports = [
    // ================================
    // Functions that are macros
    // ================================
    ["al_init", "bool", [], [], "", ""],

    ["al_malloc", "void*", [], [
        ["size_t", "n", "", []],
    ], "", ""],

    ["al_calloc", "void*", [], [
        ["size_t", "count", "", []],
        ["size_t", "n", "", []],
    ], "", ""],

    ["al_realloc", "void*", [], [
        ["void*", "ptr", "", []],
        ["size_t", "n", "", []],
    ], "", ""],

    ["al_free", "void", [], [
        ["void*", "ptr", "", []],
    ], "", ""],

    ["ALLEGRO_EVENT_TYPE_IS_USER", "bool", [], [
        ["int", "t", "", []],
    ], "", ""],

    ["ALLEGRO_GET_EVENT_TYPE", "int", [], [
        ["char", "a", "", []],
        ["char", "b", "", []],
        ["char", "c", "", []],
        ["char", "d", "", []],
    ], "", ""],

    ["ALLEGRO_USECS_TO_SECS", "double", [], [
        ["double", "x", "", []],
    ], "", ""],

    ["ALLEGRO_MSECS_TO_SECS", "double", [], [
        ["double", "x", "", []],
    ], "", ""],

    ["ALLEGRO_BPS_TO_SECS", "double", [], [
        ["double", "x", "", []],
    ], "", ""],

    ["ALLEGRO_BPM_TO_SECS", "double", [], [
        ["double", "x", "", []],
    ], "", ""],
    // ================================

    ["allegro5.", "", ["/Properties"], [
        ["bool", "ALLEGRO_WINDOWS", "", ["/RExpr=allegro5::_ALLEGRO_WINDOWS", "/C"]],
        ["int", "ALLEGRO_GTK_TOPLEVEL", "", ["/RExpr=allegro5::_ALLEGRO_GTK_TOPLEVEL", "/C"]],

        // ["char*", "ALLEGRO_EXTRA_HEADER", "", ["/RExpr=ALLEGRO_EXTRA_HEADER", "/C"]],
        // ["char*", "ALLEGRO_INTERNAL_HEADER", "", ["/RExpr=ALLEGRO_INTERNAL_HEADER", "/C"]],
        // ["char*", "ALLEGRO_INTERNAL_THREAD_HEADER", "", ["/RExpr=ALLEGRO_INTERNAL_THREAD_HEADER", "/C"]],

        ["char*", "ALLEGRO_PLATFORM_STR", "", ["/RExpr=ALLEGRO_PLATFORM_STR", "/C"]],

        // ================================
        // include/allegros/base.h
        // ================================
        ["int", "ALLEGRO_VERSION", "", ["/RExpr=ALLEGRO_VERSION", "/C"]],
        ["int", "ALLEGRO_SUB_VERSION", "", ["/RExpr=ALLEGRO_SUB_VERSION", "/C"]],
        ["int", "ALLEGRO_WIP_VERSION", "", ["/RExpr=ALLEGRO_WIP_VERSION", "/C"]],

        ["int", "ALLEGRO_UNSTABLE_BIT", "", ["/RExpr=ALLEGRO_UNSTABLE_BIT", "/C"]],

        ["int", "ALLEGRO_RELEASE_NUMBER", "", ["/RExpr=ALLEGRO_RELEASE_NUMBER", "/C"]],

        ["char*", "ALLEGRO_VERSION_STR", "", ["/RExpr=ALLEGRO_VERSION_STR", "/C"]],
        ["char*", "ALLEGRO_DATE_STR", "", ["/RExpr=ALLEGRO_DATE_STR", "/C"]],
        ["int", "ALLEGRO_DATE", "", ["/RExpr=ALLEGRO_DATE", "/C"]],
        ["int", "ALLEGRO_VERSION_INT", "", ["/RExpr=ALLEGRO_VERSION_INT", "/C"]],

        ["double", "ALLEGRO_PI", "", ["/RExpr=ALLEGRO_PI", "/C"]],
        // ================================

        // ================================
        // include/allegros/allegro_audio.h
        // ================================
        ["int", "ALLEGRO_MAX_CHANNELS", "", ["/RExpr=ALLEGRO_MAX_CHANNELS", "/C"]],
        ["float", "ALLEGRO_AUDIO_PAN_NONE", "", ["/RExpr=ALLEGRO_AUDIO_PAN_NONE", "/C"]],
        // ================================

        // ================================
        // include/allegros/allegro_primitives.h
        // ================================
        ["char", "ALLEGRO_NATIVE_PATH_SEP", "", ["/RExpr=ALLEGRO_NATIVE_PATH_SEP", "/C"]],
        ["char", "ALLEGRO_NATIVE_DRIVE_SEP", "", ["/RExpr=ALLEGRO_NATIVE_DRIVE_SEP", "/C"]],
        // ================================

        // ================================
        // include/allegros/allegro_ttf.h
        // ================================
        ["int", "ALLEGRO_TTF_MONOCHROME", "", ["/RExpr=1", "/C"]],
        ["int", "ALLEGRO_TTF_NO_AUTOHINT", "", ["/RExpr=2", "/C"]],
        ["int", "ALLEGRO_TTF_NO_KERNING", "", ["/RExpr=4", "/C"]],
        // ================================

        // ================================
        // include/allegros/display.h
        // ================================
        ["int", "ALLEGRO_NEW_WINDOW_TITLE_MAX_SIZE", "", ["/RExpr=ALLEGRO_NEW_WINDOW_TITLE_MAX_SIZE", "/C"]],
        // ================================

        // ================================
        // include/allegros/fshook.h
        // ================================
        ["int", "EOF", "", ["/RExpr=EOF", "/C"]],
        // ================================

        // ================================
        // include/allegros/mouse.h
        // ================================
        ["int", "ALLEGRO_MOUSE_MAX_EXTRA_AXES", "", ["/RExpr=ALLEGRO_MOUSE_MAX_EXTRA_AXES", "/C"]],
        // ================================

        // ================================
        // include/allegros/path.h
        // ================================
        ["int", "ALLEGRO_VERTEX_CACHE_SIZE", "", ["/RExpr=ALLEGRO_VERTEX_CACHE_SIZE", "/C"]],
        ["int", "ALLEGRO_PRIM_QUALITY", "", ["/RExpr=ALLEGRO_PRIM_QUALITY", "/C"]],
        // ================================

        // ================================
        // include/allegros/shader.h
        // ================================
        ["char*", "ALLEGRO_SHADER_VAR_COLOR", "", ["/RExpr=ALLEGRO_SHADER_VAR_COLOR", "/C"]],
        ["char*", "ALLEGRO_SHADER_VAR_POS", "", ["/RExpr=ALLEGRO_SHADER_VAR_POS", "/C"]],
        ["char*", "ALLEGRO_SHADER_VAR_PROJVIEW_MATRIX", "", ["/RExpr=ALLEGRO_SHADER_VAR_PROJVIEW_MATRIX", "/C"]],
        ["char*", "ALLEGRO_SHADER_VAR_TEX", "", ["/RExpr=ALLEGRO_SHADER_VAR_TEX", "/C"]],
        ["char*", "ALLEGRO_SHADER_VAR_TEXCOORD", "", ["/RExpr=ALLEGRO_SHADER_VAR_TEXCOORD", "/C"]],
        ["char*", "ALLEGRO_SHADER_VAR_TEX_MATRIX", "", ["/RExpr=ALLEGRO_SHADER_VAR_TEX_MATRIX", "/C"]],
        ["char*", "ALLEGRO_SHADER_VAR_USER_ATTR", "", ["/RExpr=ALLEGRO_SHADER_VAR_USER_ATTR", "/C"]],
        ["char*", "ALLEGRO_SHADER_VAR_USE_TEX", "", ["/RExpr=ALLEGRO_SHADER_VAR_USE_TEX", "/C"]],
        ["char*", "ALLEGRO_SHADER_VAR_USE_TEX_MATRIX", "", ["/RExpr=ALLEGRO_SHADER_VAR_USE_TEX_MATRIX", "/C"]],
        ["char*", "ALLEGRO_SHADER_VAR_ALPHA_TEST", "", ["/RExpr=ALLEGRO_SHADER_VAR_ALPHA_TEST", "/C"]],
        ["char*", "ALLEGRO_SHADER_VAR_ALPHA_FUNCTION", "", ["/RExpr=ALLEGRO_SHADER_VAR_ALPHA_FUNCTION", "/C"]],
        ["char*", "ALLEGRO_SHADER_VAR_ALPHA_TEST_VALUE", "", ["/RExpr=ALLEGRO_SHADER_VAR_ALPHA_TEST_VALUE", "/C"]],
        // ================================

        // ================================
        // include/allegros/touch_input.h
        // ================================
        ["int", "ALLEGRO_TOUCH_INPUT_MAX_TOUCH_COUNT", "", ["/RExpr=ALLEGRO_TOUCH_INPUT_MAX_TOUCH_COUNT", "/C"]],
        // ================================

        // ================================
        // include/allegros/internal/aintern.h
        // ================================
        ["int", "ALLEGRO_MESSAGE_SIZE", "", ["/RExpr=ALLEGRO_MESSAGE_SIZE", "/C"]],
        // ================================

        // ================================
        // include/allegros/internal/aintern_file.h
        // ================================
        ["int", "ALLEGRO_UNGETC_SIZE", "", ["/RExpr=16", "/C"]],
        // ================================

        // ================================
        // include/allegros/allegro_direct3d.h
        // ================================
        ["int", "ALLEGRO_DIRECT3D", "", ["/RExpr=ALLEGRO_DIRECT3D_INTERNAL", "/C"]],
        // ================================

        // ================================
        // include/allegros/alcompat.h
        // ================================
        ["ALLEGRO_BLEND_MODE", "ALLEGRO_DST_COLOR", "", ["/RExpr=ALLEGRO_DEST_COLOR", "/C"]],
        ["ALLEGRO_BLEND_MODE", "ALLEGRO_INVERSE_DST_COLOR", "", ["/RExpr=ALLEGRO_INVERSE_DEST_COLOR", "/C"]],

        ["al_convert_memory_bitmaps", "al_convert_bitmaps", "", ["/R", "=this", "/S"]],
        ["al_get_time", "al_current_time", "", ["/R", "=this", "/S"]],
        ["al_is_event_queue_empty", "al_event_queue_is_empty", "", ["/R", "=this", "/S"]],
        ["al_set_display_flag", "al_toggle_display_flag", "", ["/R", "=this", "/S"]],
        // ================================

        // ================================
        // addons/native_dialog/allegro5/allegro_native_dialog.h
        // ================================
        // ["std::tuple<const char *, uint16_t, int, ALLEGRO_BITMAP *>", "ALLEGRO_MENU_SEPARATOR", "", ["/RExpr=ALLEGRO_MENU_SEPARATOR", "/C"]],
        // ["ALLEGRO_START_OF_MENU", "std::tuple<const char *, uint16_t, int, ALLEGRO_BITMAP *>", [], [
        //     ["const char *", "caption", "", []],
        //     ["uint16_t", "id", "", []],
        // ], "", ""],
        // ["std::tuple<const char *, uint16_t, int, ALLEGRO_BITMAP *>", "ALLEGRO_END_OF_MENU", "", ["/RExpr=ALLEGRO_END_OF_MENU", "/C"]],
        // ================================

    ], "", ""],
];
