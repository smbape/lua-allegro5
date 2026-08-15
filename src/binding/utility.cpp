#include <lua_bridge.hpp>

namespace allegro5 {
#ifdef ALLEGRO_WINDOWS
	const bool _ALLEGRO_WINDOWS = true;
#else
	const bool _ALLEGRO_WINDOWS = false;
#endif

#ifdef ALLEGRO_GTK_TOPLEVEL
	const int _ALLEGRO_GTK_TOPLEVEL = ALLEGRO_GTK_TOPLEVEL;
#else
	const int _ALLEGRO_GTK_TOPLEVEL = 0;
#endif

	const std::string& getBuildInformation() {
		static std::string build_info =
#include "version_string.inc"
			;
		return build_info;
	}

	void string_array(int argc, void* ptr, std::vector<std::string>& out) {
		auto argv = static_cast<char**>(ptr);
		out.reserve(argc);
		for (int i = 0; i < argc; i++) {
			out[i] = std::string(argv[i]);
		}
	}
}
