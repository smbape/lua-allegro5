#include <condition_variable>
#include <lua_bridge.hpp>
// #include <regex>

// defined in cffi-lua/src/ffilib.cc
void ffi_module_open(lua_State* L);

namespace {
	using namespace LUA_MODULE_NAME;

	void register_ffi(lua_State* L) {
		lua_pushliteral(L, "ffi");
		ffi_module_open(L);
		lua_rawset(L, -3);
	}

	// https://devblogs.microsoft.com/oldnewthing/20190710-00/?p=102678

	void register_cdef(lua_State* L) {
		std::ostringstream oss;

		oss << "typedef " << internal::GetTypeName<off_t>() << " off_t;\n";
		oss << "typedef " << internal::GetTypeName<time_t>() << " time_t;\n";
		oss << "typedef " << internal::GetTypeName<clock_t>() << " clock_t;\n";

#ifdef _MSC_VER
		oss << "typedef " << internal::GetTypeName<DWORD>() << " DWORD;\n";
		oss << "typedef " << internal::GetTypeName<BOOL>() << " BOOL;\n";
		oss << "typedef " << internal::GetTypeName<BYTE>() << " BYTE;\n";
		oss << "typedef " << internal::GetTypeName<WORD>() << " WORD;\n";
		oss << "typedef " << internal::GetTypeName<FLOAT>() << " FLOAT;\n";
		oss << "typedef " << internal::GetTypeName<PFLOAT>() << " PFLOAT;\n";
		oss << "typedef " << internal::GetTypeName<PBOOL>() << " PBOOL;\n";
		oss << "typedef " << internal::GetTypeName<LPBOOL>() << " LPBOOL;\n";
		oss << "typedef " << internal::GetTypeName<PBYTE>() << " PBYTE;\n";
		oss << "typedef " << internal::GetTypeName<LPBYTE>() << " LPBYTE;\n";
		oss << "typedef " << internal::GetTypeName<PINT>() << " PINT;\n";
		oss << "typedef " << internal::GetTypeName<LPINT>() << " LPINT;\n";
		oss << "typedef " << internal::GetTypeName<PWORD>() << " PWORD;\n";
		oss << "typedef " << internal::GetTypeName<LPWORD>() << " LPWORD;\n";
		oss << "typedef " << internal::GetTypeName<LPLONG>() << " LPLONG;\n";
		oss << "typedef " << internal::GetTypeName<PDWORD>() << " PDWORD;\n";
		oss << "typedef " << internal::GetTypeName<LPDWORD>() << " LPDWORD;\n";
		oss << "typedef " << internal::GetTypeName<LPVOID>() << " LPVOID;\n";
		oss << "typedef " << internal::GetTypeName<LPCVOID>() << " LPCVOID;\n";
		oss << "typedef " << internal::GetTypeName<INT>() << " INT;\n";
		oss << "typedef " << internal::GetTypeName<UINT>() << " UINT;\n";
		oss << "typedef " << internal::GetTypeName<PUINT>() << " PUINT;\n";

		oss << "typedef " << internal::GetTypeName<CHAR>() << " CHAR;\n";
		oss << "typedef " << internal::GetTypeName<SHORT>() << " SHORT;\n";
		oss << "typedef " << internal::GetTypeName<LONG>() << " LONG;\n";

		oss << "typedef " << internal::GetTypeName<HWND>() << " HWND;\n";
		oss << "typedef " << internal::GetTypeName<WPARAM>() << " WPARAM;\n";
		oss << "typedef " << internal::GetTypeName<LPARAM>() << " LPARAM;\n";
		oss << "typedef " << internal::GetTypeName<LRESULT>() << " LRESULT;\n";
#endif

#ifdef GL_VERSION
		oss << "typedef " << internal::GetTypeName<GLenum>() << " GLenum;\n";
		oss << "typedef " << internal::GetTypeName<GLboolean>() << " GLboolean;\n";
		oss << "typedef " << internal::GetTypeName<GLbitfield>() << " GLbitfield;\n";
		oss << "typedef " << internal::GetTypeName<GLbyte>() << " GLbyte;\n";
		oss << "typedef " << internal::GetTypeName<GLshort>() << " GLshort;\n";
		oss << "typedef " << internal::GetTypeName<GLint>() << " GLint;\n";
		oss << "typedef " << internal::GetTypeName<GLsizei>() << " GLsizei;\n";
		oss << "typedef " << internal::GetTypeName<GLubyte>() << " GLubyte;\n";
		oss << "typedef " << internal::GetTypeName<GLushort>() << " GLushort;\n";
		oss << "typedef " << internal::GetTypeName<GLuint>() << " GLuint;\n";
		oss << "typedef " << internal::GetTypeName<GLfloat>() << " GLfloat;\n";
		oss << "typedef " << internal::GetTypeName<GLclampf>() << " GLclampf;\n";
		oss << "typedef " << internal::GetTypeName<GLdouble>() << " GLdouble;\n";
		oss << "typedef " << internal::GetTypeName<GLclampd>() << " GLclampd;\n";
		oss << "typedef " << internal::GetTypeName<GLvoid>() << " GLvoid;\n";
		oss << "typedef " << internal::GetTypeName<GLint64>() << " GLint64;\n";
		oss << "typedef " << internal::GetTypeName<GLuint64>() << " GLuint64;\n";
		oss << "typedef " << internal::GetTypeName<GLintptr>() << " GLintptr;\n";
		oss << "typedef " << internal::GetTypeName<GLsizeiptr>() << " GLsizeiptr;\n";
		oss << "typedef " << internal::GetTypeName<GLchar>() << " GLchar;\n";
#endif

#ifdef X_PROTOCOL
		oss << "typedef " << internal::GetTypeName<XID>() << " XID;\n";
		oss << "typedef struct _XDisplay Display;\n";
#endif

#ifdef GLX_VERSION
		oss << "typedef " << internal::GetTypeName<GLXPixmap>() << " GLXPixmap;\n";
		oss << "typedef " << internal::GetTypeName<GLXDrawable>() << " GLXDrawable;\n";
#endif

#ifdef DIRECT3D_VERSION
		oss << "typedef " << internal::GetTypeName<LPDIRECT3DDEVICE9>() << " LPDIRECT3DDEVICE9;\n";
		oss << "typedef " << internal::GetTypeName<LPDIRECT3DTEXTURE9>() << " LPDIRECT3DTEXTURE9;\n";
		oss << "typedef " << internal::GetTypeName<LPDIRECT3DTEXTURE9>() << " LPDIRECT3DTEXTURE9;\n";
#endif

		lua_pushliteral(L, "cdef");
		lua_push(L, oss.str());
		lua_rawset(L, -3);
	}

	// ================================
	// register callback
	// ================================

	class RegisteredFunctionInvoker {
	public:
		static void function_binding(ffi_cif* cif, void* ret, void** args, void* user_data);

		RegisteredFunctionInvoker(
			const Function& fn,
			const std::string& return_type,
			FFIArgExtractor* return_extractor,
			std::vector<FFIArgExtractor*>&& arg_extractors
		);

		~RegisteredFunctionInvoker();

		void invoke(ffi_cif* cif, void* ret, void** args);

		void* bound_function { nullptr };
	private:
		Function fn;
		std::shared_ptr<std::mutex> creator_gil_mutex;
		std::thread::id creator_thread_id;
		std::shared_ptr<std::unique_lock<std::mutex>> creator_gil;
		std::string return_type;
		FFIArgExtractor* return_extractor;
		std::vector<FFIArgExtractor*> arg_extractors;

		std::vector<ffi_type*> atypes;
		ffi_closure* closure { nullptr };
		ffi_cif cif;

		std::unique_ptr<std::jthread> m_thread;
		bool m_thread_ready = false;
		std::mutex m_mutex;
		std::condition_variable_any m_cv;
		bool m_has_data = false;
	};

	RegisteredFunctionInvoker::RegisteredFunctionInvoker(
		const Function& _fn,
		const std::string& _return_type,
		FFIArgExtractor* _return_extractor,
		std::vector<FFIArgExtractor*>&& _arg_extractors
	) :
		fn(_fn),
		return_type(_return_type),
		return_extractor(_return_extractor),
		arg_extractors(std::move(_arg_extractors))
	{
		auto L = fn.L;
		creator_gil_mutex = get_gil_mutex(L);
		creator_thread_id = std::this_thread::get_id();
		creator_gil = get_thread_gil(L, creator_gil_mutex);

		/* Allocate closure and bound_function */
		closure = reinterpret_cast<ffi_closure*>(ffi_closure_alloc(sizeof(ffi_closure), &bound_function));
		if (!closure) {
			luaL_error(L, "Failed to allocate the closure");
			return;
		}

		const auto nargs = arg_extractors.size();
		const auto rtype = return_extractor ? return_extractor->ffi_type_ptr : &ffi_type_void;

		if (nargs != 0) {
			atypes.resize(nargs, nullptr);

			for (auto i = 0; i < nargs; i++) {
				atypes[i] = arg_extractors[i]->ffi_type_ptr;
			}
		}

		/* Initialize the cif */
		if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, nargs, rtype, atypes.data()) != FFI_OK) {
			ffi_closure_free(closure);
			luaL_error(L, "Failed to initialize the cif");
			return;
		}

		/* Initialize the closure */
		if (ffi_prep_closure_loc(closure, &cif, &RegisteredFunctionInvoker::function_binding, this, bound_function) != FFI_OK) {
			ffi_closure_free(closure);
			luaL_error(L, "Failed to initialize the cif");
			return;
		}
	};

	RegisteredFunctionInvoker::~RegisteredFunctionInvoker() {
		if (closure) {
			ffi_closure_free(closure);
		}
	}

	void RegisteredFunctionInvoker::invoke(ffi_cif* cif, void* ret, void** args) {
		auto& L = fn.L;
		GilLock lock(L, creator_gil_mutex, creator_thread_id, creator_gil);

		lua_push(L, fn);

		for (std::size_t i = 0; i < arg_extractors.size(); ++i) {
			arg_extractors[i]->push(L, args[i]);
		}

		lua_call(L, arg_extractors.size(), return_extractor ? 1 : 0);

		if (return_extractor) {
			bool is_valid = false;
			auto rc = return_extractor->extract(L, -1, is_valid);
			if (!is_valid) {
				LUAL_MODULE_ERROR(L, "bad argument #1 to 'register_callback' (cannot convert '" << ::LUA_MODULE_NAME::internal::LuaTypeName(L, 1) << "' to '" << return_type << "')");
			}
			return_extractor->copy(&ret, rc);
			return_extractor->destroy(rc);
			lua_pop(L, 1);
		}
	}

	void RegisteredFunctionInvoker::function_binding(ffi_cif* cif, void* ret, void** args, void* user_data) {
		auto invoker = static_cast<RegisteredFunctionInvoker*>(user_data);
		invoker->invoke(cif, ret, args);
	}

	std::unordered_map<void*, std::unique_ptr<RegisteredFunctionInvoker>> registered_callbacks;

	int register_callback(lua_State* L) {
		auto vargc = lua_gettop(L);

		bool is_valid = vargc >= 2;
		if (!is_valid) {
			LUAL_MODULE_ERROR_RETURN(L, "bad number of arguments to 'register_callback' (expecting at least 2, given " << vargc << ")");
		}

		auto fn = lua_to(L, 1, static_cast<Function*>(nullptr), is_valid);
		if (!is_valid) {
			LUAL_MODULE_ERROR_RETURN(L, "bad argument #1 to 'register_callback' (cannot convert '" << ::LUA_MODULE_NAME::internal::LuaTypeName(L, 1) << "' to 'function')");
		}

		auto return_type = lua_to(L, 2, static_cast<std::string*>(nullptr), is_valid);
		if (!is_valid) {
			LUAL_MODULE_ERROR_RETURN(L, "bad argument #2 to 'register_callback' (cannot convert '" << ::LUA_MODULE_NAME::internal::LuaTypeName(L, 2) << "' to 'std::string')");
		}

		FFIArgExtractor* return_extractor = nullptr;
		if (return_type != "void") {
			return_extractor = get_extractor(return_type);
			if (!return_extractor) {
				LUAL_MODULE_ERROR_RETURN(L, "bad argument #2 to 'register_callback' (missing declaration for symbol '" << return_type << "')");
			}
		}

		auto argi = 3;
		std::vector<FFIArgExtractor*> arg_extractors(vargc - argi + 1, nullptr);

		for (auto i = 0; i < vargc - argi + 1; i++) {
			auto arg_type = lua_to(L, i + argi, static_cast<std::string*>(nullptr), is_valid);
			if (!is_valid) {
				LUAL_MODULE_ERROR_RETURN(L, "bad argument #" << (i + argi) << " to 'register_callback' (cannot convert '" << ::LUA_MODULE_NAME::internal::LuaTypeName(L, i + argi) << "' to 'std::string')");
			}

			// TODO : remove const qualifiers

			arg_extractors[i] = get_extractor(arg_type);
			if (!arg_extractors[i]) {
				LUAL_MODULE_ERROR_RETURN(L, "bad argument #" << (i + argi) << " to 'register_callback' (missing declaration for symbol '" << arg_type << "')");
			}
		}

		auto invoker = std::make_unique<RegisteredFunctionInvoker>(
			fn,
			return_type,
			return_extractor,
			std::move(arg_extractors)
		);

		auto bound_function = invoker->bound_function;
		registered_callbacks.insert_or_assign(bound_function, std::move(invoker));
		lua_pushlightuserdata(L, bound_function);

		return 1;
	}

	int unregister_callback(lua_State* L) {
		auto vargc = lua_gettop(L);

		bool is_valid = vargc == 1;
		if (!is_valid) {
			LUAL_MODULE_ERROR_RETURN(L, "bad number of arguments to 'unregister_callback' (expecting at 1, given " << vargc << ")");
		}

		auto bound_function = lua_to(L, 1, static_cast<void**>(nullptr), is_valid);
		if (!is_valid) {
			LUAL_MODULE_ERROR_RETURN(L, "bad argument #1 to 'unregister_callback' (cannot convert '" << ::LUA_MODULE_NAME::internal::LuaTypeName(L, 1) << "' to 'void*')");
		}

		registered_callbacks.erase(bound_function);

		return 0;
	}

	void register_register_callback(lua_State* L) {
		const struct luaL_Reg lua_instance_misc_methods[] = {
			{"register_callback", register_callback},
			{"unregister_callback", unregister_callback},
			{NULL, NULL} // Sentinel
		};
		lua_pushfuncs(L, lua_instance_misc_methods);
	}

	// ================================
	// register defered callback
	// ================================

	class DeferedFunctionInvoker {
	public:
		static void function_binding(ffi_cif* cif, void* ret, void** args, void* user_data);
		static void thread_invoke(std::stop_token stoken, DeferedFunctionInvoker* invoker);

		DeferedFunctionInvoker(
			const Function& fn,
			void* _ret,
			FFIArgExtractor* return_extractor,
			std::vector<FFIArgExtractor*>&& arg_extractors
		);

		~DeferedFunctionInvoker();

		void invoke(std::stop_token& stoken);
		void defer(ffi_cif* cif, void* ret, void** args);

		void* bound_function { nullptr };
	private:
		Function fn;
		std::shared_ptr<std::mutex> creator_gil_mutex;
		std::thread::id creator_thread_id;
		std::shared_ptr<std::unique_lock<std::mutex>> creator_gil;
		void* ret;
		FFIArgExtractor* return_extractor;
		std::vector<FFIArgExtractor*> arg_extractors;

		std::vector<ffi_type*> atypes;
		std::vector<void*> args;
		ffi_closure* closure { nullptr };
		ffi_cif cif;

		std::unique_ptr<std::jthread> m_thread;
		bool m_thread_ready = false;
		std::mutex m_mutex;
		std::condition_variable_any m_cv;
		bool m_has_data = false;
	};

	DeferedFunctionInvoker::DeferedFunctionInvoker(
		const Function& _fn,
		void* _ret,
		FFIArgExtractor* _return_extractor,
		std::vector<FFIArgExtractor*>&& _arg_extractors
	) :
		fn(_fn),
		ret(_ret),
		return_extractor(_return_extractor),
		arg_extractors(std::move(_arg_extractors))
	{
		auto L = fn.L;
		creator_gil_mutex = get_gil_mutex(L);
		creator_thread_id = std::this_thread::get_id();
		creator_gil = get_thread_gil(L, creator_gil_mutex);

		/* Allocate closure and bound_function */
		closure = reinterpret_cast<ffi_closure*>(ffi_closure_alloc(sizeof(ffi_closure), &bound_function));
		if (!closure) {
			luaL_error(L, "Failed to allocate the closure");
			return;
		}

		const auto nargs = arg_extractors.size();
		const auto rtype = return_extractor ? return_extractor->ffi_type_ptr : &ffi_type_void;

		if (nargs != 0) {
			args.resize(nargs, nullptr);
			atypes.resize(nargs, nullptr);

			for (auto i = 0; i < nargs; i++) {
				atypes[i] = arg_extractors[i]->ffi_type_ptr;
			}
		}

		/* Initialize the cif */
		if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, nargs, rtype, atypes.data()) != FFI_OK) {
			ffi_closure_free(closure);
			luaL_error(L, "Failed to initialize the cif");
			return;
		}

		/* Initialize the closure */
		if (ffi_prep_closure_loc(closure, &cif, &DeferedFunctionInvoker::function_binding, this, bound_function) != FFI_OK) {
			ffi_closure_free(closure);
			luaL_error(L, "Failed to initialize the cif");
			return;
		}
	};

	DeferedFunctionInvoker::~DeferedFunctionInvoker() {
		if (closure) {
			ffi_closure_free(closure);
		}

		if (m_thread) {
			m_thread->request_stop();
			m_thread->join();
		}

		if (return_extractor) {
			return_extractor->destroy(ret);
		}

		for (std::size_t i = 0; i < arg_extractors.size(); ++i) {
			arg_extractors[i]->destroy(args[i]);
		}
	}

	void DeferedFunctionInvoker::thread_invoke(std::stop_token stoken, DeferedFunctionInvoker* invoker) {
		invoker->invoke(stoken);
	}

	void DeferedFunctionInvoker::invoke(std::stop_token& stoken) {
		{
			std::unique_lock m_lock(m_mutex);
			m_thread_ready = true;
			m_cv.notify_all();
		}

		while (!stoken.stop_requested()) {
			std::unique_lock m_lock(m_mutex);
			if (!m_has_data) {
				m_cv.wait(m_lock, stoken, [this]{ return m_has_data; });
				continue;
			}
			m_lock.unlock();

			auto& L = fn.L;
			GilLock lock(L, creator_gil_mutex, creator_thread_id, creator_gil);

			m_lock.lock();

			lua_push(L, fn);

			for (std::size_t i = 0; i < arg_extractors.size(); ++i) {
				arg_extractors[i]->push(L, args[i]);
			}

			lua_call(L, arg_extractors.size(), return_extractor ? 1 : 0);

			if (return_extractor) {
				lua_pop(L, 1);
			}

			m_has_data = false;
			m_cv.notify_all();
		}
	}

	void DeferedFunctionInvoker::defer(ffi_cif* cif, void* ret, void** args) {
		if (!m_thread) {
			m_thread = std::make_unique<std::jthread>(DeferedFunctionInvoker::thread_invoke, this);
			std::unique_lock m_lock(m_mutex);
			if (!m_thread_ready) {
				m_cv.wait(m_lock, [this]{ return m_thread_ready; });
			}
		}

		std::unique_lock m_lock(m_mutex);

		if (return_extractor) {
			return_extractor->copy(&ret, this->ret);
		}

		for (std::size_t i = 0; i < arg_extractors.size(); ++i) {
			arg_extractors[i]->destroy(this->args.at(i));
			arg_extractors[i]->copy(&this->args.at(i), args[i]);
		}

		m_has_data = true;
	}

	void DeferedFunctionInvoker::function_binding(ffi_cif* cif, void* ret, void** args, void* user_data) {
		auto invoker = static_cast<DeferedFunctionInvoker*>(user_data);
		invoker->defer(cif, ret, args);
	}

	std::unordered_map<void*, std::unique_ptr<DeferedFunctionInvoker>> registered_defered_functions;

	int register_defered_callback(lua_State* L) {
		auto vargc = lua_gettop(L);

		bool is_valid = vargc >= 2;
		if (!is_valid) {
			LUAL_MODULE_ERROR_RETURN(L, "bad number of arguments to 'register_defered_callback' (expecting at least 2, given " << vargc << ")");
		}

		auto fn = lua_to(L, 1, static_cast<Function*>(nullptr), is_valid);
		if (!is_valid) {
			LUAL_MODULE_ERROR_RETURN(L, "bad argument #1 to 'register_defered_callback' (cannot convert '" << ::LUA_MODULE_NAME::internal::LuaTypeName(L, 1) << "' to 'function')");
		}

		auto return_type = lua_to(L, 2, static_cast<std::string*>(nullptr), is_valid);
		if (!is_valid) {
			LUAL_MODULE_ERROR_RETURN(L, "bad argument #2 to 'register_defered_callback' (cannot convert '" << ::LUA_MODULE_NAME::internal::LuaTypeName(L, 2) << "' to 'std::string')");
		}

		auto argi = 3;
		void* ret = nullptr;

		FFIArgExtractor* return_extractor = nullptr;
		if (return_type != "void") {
			return_extractor = get_extractor(return_type);
			if (!return_extractor) {
				LUAL_MODULE_ERROR_RETURN(L, "bad argument #2 to 'register_defered_callback' (missing declaration for symbol '" << return_type << "')");
			}

			ret = return_extractor->extract(L, argi++, is_valid);
			if (!is_valid) {
				LUAL_MODULE_ERROR_RETURN(L, "bad argument #3 to 'register_defered_callback' (cannot convert '" << ::LUA_MODULE_NAME::internal::LuaTypeName(L, 3) << "' to '" << return_type << "')");
			}
		}

		std::vector<FFIArgExtractor*> arg_extractors(vargc - argi + 1, nullptr);

		for (auto i = 0; i < vargc - argi + 1; i++) {
			auto arg_type = lua_to(L, i + argi, static_cast<std::string*>(nullptr), is_valid);
			if (!is_valid) {
				LUAL_MODULE_ERROR_RETURN(L, "bad argument #" << (i + argi) << " to 'register_defered_callback' (cannot convert '" << ::LUA_MODULE_NAME::internal::LuaTypeName(L, i + argi) << "' to 'std::string')");
			}

			// TODO : remove const qualifiers

			arg_extractors[i] = get_extractor(arg_type);
			if (!arg_extractors[i]) {
				LUAL_MODULE_ERROR_RETURN(L, "bad argument #" << (i + argi) << " to 'register_defered_callback' (missing declaration for symbol '" << arg_type << "')");
			}
		}

		auto invoker = std::make_unique<DeferedFunctionInvoker>(
			fn,
			ret,
			return_extractor,
			std::move(arg_extractors)
		);

		auto bound_function = invoker->bound_function;
		registered_defered_functions.insert_or_assign(bound_function, std::move(invoker));
		lua_pushlightuserdata(L, bound_function);

		return 1;
	}

	int unregister_defered_callback(lua_State* L) {
		auto vargc = lua_gettop(L);

		bool is_valid = vargc == 1;
		if (!is_valid) {
			LUAL_MODULE_ERROR_RETURN(L, "bad number of arguments to 'unregister_defered_callback' (expecting at 1, given " << vargc << ")");
		}

		auto bound_function = lua_to(L, 1, static_cast<void**>(nullptr), is_valid);
		if (!is_valid) {
			LUAL_MODULE_ERROR_RETURN(L, "bad argument #1 to 'unregister_defered_callback' (cannot convert '" << ::LUA_MODULE_NAME::internal::LuaTypeName(L, 1) << "' to 'void*')");
		}

		registered_defered_functions.erase(bound_function);

		return 0;
	}

	void register_register_defered_callback(lua_State* L) {
		const struct luaL_Reg lua_instance_misc_methods[] = {
			{"register_defered_callback", register_defered_callback},
			{"unregister_defered_callback", unregister_defered_callback},
			{NULL, NULL} // Sentinel
		};
		lua_pushfuncs(L, lua_instance_misc_methods);
	}

	std::unordered_map<std::string, FFIArgExtractor> extractors;

	int handle_exit(lua_State* L = nullptr) {
		if (al_is_system_installed()) {
			al_uninstall_system();
		}
		return 0;
	}

	struct OnExit {
		~OnExit() {
			handle_exit();
		}
	};

	std::mutex onexit_mutex;

	lua_CFunction old_panicf;

	int handle_panic(lua_State* L) {
		handle_exit(L);
		if (old_panicf) {
			return old_panicf(L);
		}
		return 0;
	}

	void register_onexit(lua_State* L) {
		static std::unique_ptr<OnExit> onexit;

		std::unique_lock onexit_lock(onexit_mutex);

		if (onexit) {
			return;
		}

		auto userdata_ptr = lua_newuserdata(L, sizeof(void*));

		lua_newtable(L);
		lua_pushstring(L, "__gc");
		lua_pushcfunction(L, handle_exit);
		lua_rawset(L, -3);

		lua_setmetatable(L, -2);
		luaL_ref(L, LUA_REGISTRYINDEX); // save last value

		old_panicf = lua_atpanic(L, handle_panic);

		onexit = std::make_unique<OnExit>();
	}
}

namespace LUA_MODULE_NAME {
	void register_extractor(const std::string& key, const FFIArgExtractor& extractor) {
		extractors.insert_or_assign(key, extractor);
	}

	FFIArgExtractor* get_extractor(const std::string& key) {
		auto search = extractors.find(key);
		if (search != extractors.end()) {
			return &search->second;
		}
		return nullptr;
	}

	void register_extensions(lua_State* L) {
		register_ffi(L);
		register_cdef(L);
		register_extractors();
		register_register_callback(L);
		register_register_defered_callback(L);
		register_onexit(L);
	}
}
