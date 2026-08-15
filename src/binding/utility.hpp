#pragma once
#include <luadef.hpp>

namespace allegro5 {
	extern const bool _ALLEGRO_WINDOWS;
	extern const int _ALLEGRO_GTK_TOPLEVEL;

	/** @brief Returns full configuration time cmake output.

	Returned value is the cmake output configuration summary.
	 */
	CV_EXPORTS_W const std::string& getBuildInformation();

	CV_EXPORTS_W void string_array(int argc, void* ptr, CV_OUT std::vector<std::string>& out);
}
