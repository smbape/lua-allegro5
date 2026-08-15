#include <cstdint>
#include <cstdio>
#include <type_traits>
#include <time.h>
#include <sys/types.h>
#include <allegro5/allegro.h>

// https://github.com/Manu343726/ctti/blob/master/include/ctti/detail/pretty_function.hpp#L10-L18
#if defined(__clang__)
    #define PRETTY_FUNCTION __PRETTY_FUNCTION__
#elif defined(__GNUC__) && !defined(__clang__)
    #define PRETTY_FUNCTION __PRETTY_FUNCTION__
#elif defined(_MSC_VER)
    #define PRETTY_FUNCTION __FUNCSIG__
#else
    #error "No support for this compiler."
#endif

// https://github.com/Manu343726/ctti/blob/master/include/ctti/detail/pretty_function.hpp#L42-L53
#if defined(__clang__)
    #define TYPE_PRETTY_FUNCTION_PREFIX "const char* internal::GetTypeName() [T = "
    #define TYPE_PRETTY_FUNCTION_SUFFIX "]"
#elif defined(__GNUC__) && !defined(__clang__)
    #define TYPE_PRETTY_FUNCTION_PREFIX "const char* internal::GetTypeName() [with T = "
    #define TYPE_PRETTY_FUNCTION_SUFFIX "]"
#elif defined(_MSC_VER)
    #define TYPE_PRETTY_FUNCTION_PREFIX "const char *__cdecl internal::GetTypeName<"
    #define TYPE_PRETTY_FUNCTION_SUFFIX ">(void)"
#else
    #error "No support for this compiler."
#endif

#define TYPE_PRETTY_FUNCTION_LEFT (sizeof(TYPE_PRETTY_FUNCTION_PREFIX) - 1)
#define TYPE_PRETTY_FUNCTION_RIGHT (sizeof(TYPE_PRETTY_FUNCTION_SUFFIX) - 1)

// https://blog.molecular-matters.com/2015/12/11/getting-the-type-of-a-template-argument-as-string-without-rtti/
namespace internal {
    template <typename T>
    const char* GetTypeName(void) {
        constexpr size_t size = sizeof(PRETTY_FUNCTION) - TYPE_PRETTY_FUNCTION_LEFT - TYPE_PRETTY_FUNCTION_RIGHT;
        static char typeName[size] = {};
        memcpy(typeName, PRETTY_FUNCTION + TYPE_PRETTY_FUNCTION_LEFT, size - 1u);
        return typeName;
        // return PRETTY_FUNCTION;
    }
}

int main(int argc, char **argv) {
    std::printf("typedef %s %s;\n", internal::GetTypeName<int8_t>(), "int8_t");
    std::printf("typedef %s %s;\n", internal::GetTypeName<uint8_t>(), "uint8_t");
    std::printf("typedef %s %s;\n", internal::GetTypeName<int16_t>(), "int16_t");
    std::printf("typedef %s %s;\n", internal::GetTypeName<uint16_t>(), "uint16_t");
    std::printf("typedef %s %s;\n", internal::GetTypeName<int32_t>(), "int32_t");
    std::printf("typedef %s %s;\n", internal::GetTypeName<uint32_t>(), "uint32_t");
    std::printf("typedef %s %s;\n", internal::GetTypeName<int64_t>(), "int64_t");
    std::printf("typedef %s %s;\n", internal::GetTypeName<uint64_t>(), "uint64_t");
    std::printf("typedef %s %s;\n", internal::GetTypeName<off_t>(), "off_t");
    std::printf("typedef %s %s;\n", internal::GetTypeName<time_t>(), "time_t");
    std::printf("typedef %s %s;\n", internal::GetTypeName<clock_t>(), "clock_t");
    std::printf("typedef %s %s;\n", internal::GetTypeName<ALLEGRO_USTR_INFO>(), "ALLEGRO_USTR_INFO");
    std::printf("typedef %s %s;\n", internal::GetTypeName<ALLEGRO_USTR>(), "ALLEGRO_USTR");
    return 0;
}
