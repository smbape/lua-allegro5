#pragma once

#include <lua_bridge_common.hdr.hpp>
#include <lua_bridge.hdr.hpp>
#include <lua_bridge_ffi_types.hdr.hpp>

#include <lua_generated_include.hpp>
#include <register_all.hpp>

#include <lua_bridge_common.hpp>
#include <ffi.hh>

namespace LUA_MODULE_NAME {
	// ================================
	// bool
	// ================================

	template<typename T>
	T lua_to_custom_bridge<T, std::enable_if_t<std::is_same_v<T, bool>>>::lua_to(lua_State* L, int index, bool& is_valid) {
		using namespace ffi;
		is_valid = false;

		if (iscdata(L, index)) {
			auto& cd = *lua::touserdata<cdata>(L, index);
			const auto& tp = cd.decl;
			void *value = cd.as_ptr();
			switch (tp.type()) {
				case ast::C_BUILTIN_BOOL:
					is_valid = true;
					return *static_cast<bool const *>(value);
			}
		}

		return false;
	}


	// ================================
	// std::integral
	// ================================

	template<typename T>
	T lua_to_custom_bridge<T, std::enable_if_t<std::is_integral_v<T> && !std::is_same_v<bool, std::decay_t<T>>>>::lua_to(lua_State* L, int index, bool& is_valid) {
		using namespace ffi;
		is_valid = false;

		if (iscdata(L, index)) {
			auto& cd = *lua::touserdata<cdata>(L, index);
			const auto& tp = cd.decl;
			void *value = cd.as_ptr();
			switch (tp.type()) {
				case ast::C_BUILTIN_BOOL:
					is_valid = true;
					return static_cast<T>(*static_cast<bool const *>(value));
				case ast::C_BUILTIN_CHAR:
					is_valid = true;
					return static_cast<T>(*static_cast<char*>(value));
				case ast::C_BUILTIN_SCHAR:
					is_valid = true;
					return static_cast<T>(*static_cast<signed char*>(value));
				case ast::C_BUILTIN_UCHAR:
					is_valid = true;
					return static_cast<T>(*static_cast<unsigned char*>(value));
				case ast::C_BUILTIN_SHORT:
					is_valid = true;
					return static_cast<T>(*static_cast<short*>(value));
				case ast::C_BUILTIN_USHORT:
					is_valid = true;
					return static_cast<T>(*static_cast<unsigned short*>(value));
				case ast::C_BUILTIN_INT:
					is_valid = true;
					return static_cast<T>(*static_cast<int*>(value));
				case ast::C_BUILTIN_UINT:
					is_valid = true;
					return static_cast<T>(*static_cast<unsigned int*>(value));
				case ast::C_BUILTIN_LONG:
					is_valid = true;
					return static_cast<T>(*static_cast<long*>(value));
				case ast::C_BUILTIN_ULONG:
					is_valid = true;
					return static_cast<T>(*static_cast<unsigned long*>(value));
				case ast::C_BUILTIN_LLONG:
					is_valid = true;
					return static_cast<T>(*static_cast<long long*>(value));
				case ast::C_BUILTIN_ULLONG:
					is_valid = true;
					return static_cast<T>(*static_cast<unsigned long long*>(value));
			}
		}

		return 0;
	}


	// ================================
	// std::floating_point
	// ================================

	template<typename T>
	T lua_to_custom_bridge<T, std::enable_if_t<std::is_floating_point_v<T>>>::lua_to(lua_State* L, int index, bool& is_valid) {
		using namespace ffi;
		is_valid = false;

		if (iscdata(L, index)) {
			auto& cd = *lua::touserdata<cdata>(L, index);
			const auto& tp = cd.decl;
			void *value = cd.as_ptr();
			switch (tp.type()) {
				case ast::C_BUILTIN_FLOAT:
					is_valid = true;
					return static_cast<T>(*static_cast<float*>(value));
				case ast::C_BUILTIN_DOUBLE:
					is_valid = true;
					return static_cast<T>(*static_cast<double*>(value));
				case ast::C_BUILTIN_LDOUBLE:
					is_valid = true;
					return static_cast<T>(*static_cast<long double*>(value));
				case ast::C_BUILTIN_ULLONG:
					is_valid = true;
					return static_cast<T>(*static_cast<unsigned long long*>(value));
			}
		}

		return 0;
	}


	// ================================
	// void*
	// ================================

	template<typename T>
	T lua_to_custom_bridge<T, std::enable_if_t<std::is_same_v<T, void*>>>::lua_to(lua_State* L, int index, bool& is_valid) {
		using namespace ffi;
		is_valid = false;

		if (iscdata(L, index)) {
			auto& cd = *lua::touserdata<cdata>(L, index);
			const auto& tp = cd.decl;
			switch (tp.type()) {
				case ast::C_BUILTIN_ARRAY:
				case ast::C_BUILTIN_FUNC:
				case ast::C_BUILTIN_PTR:
				case ast::C_BUILTIN_RECORD:
					is_valid = true;
					return cd.address_of();
			}
		}

		return nullptr;
	}


	// ================================
	// T*
	// ================================

	template<typename T>
	T lua_to_custom_bridge<T, std::enable_if_t<is_usertype_pointer_v<T>>>::lua_to(lua_State* L, int index, bool& is_valid) {
		using namespace ffi;
		is_valid = false;

		if (iscdata(L, index)) {
			// TODO : void* or strict type check
			auto& cd = *lua::touserdata<cdata>(L, index);
			const auto& tp = cd.decl;
			switch (tp.type()) {
				case ast::C_BUILTIN_ARRAY:
				case ast::C_BUILTIN_FUNC:
				case ast::C_BUILTIN_PTR:
				case ast::C_BUILTIN_RECORD:
					is_valid = true;
					return static_cast<T>(cd.address_of());
			}
		}

		return nullptr;
	}


	// ================================
	// fixed-size array
	// ================================

	template<typename T, size_t ...Dims>
	void FixedSizeArrayBase<T, Dims...>::register_class(lua_State* L) {
		thread_local auto registered = [L]() -> bool {
			using _ArrayT = FixedSizeArray<T, Dims...>;

			bool registered;
			{
				std::unique_lock lock(usertype_info<_ArrayT>::mutex);
				const auto index = get_luaopen_index(L);
				const auto size = usertype_info<_ArrayT>::metatable_pointers.size();
				registered = index < size && usertype_info<_ArrayT>::metatable_refs.at(index) != LUA_REFNIL;
			}

			if (!registered) {
				lua_newtable(L);
				lua_register_class<_ArrayT>(L, internal::GetTypeName<_ArrayT>());
				lua_register_defaults<_ArrayT>(L);

				{
					lua_pushstring(L, internal::GetTypeName<_ArrayT>());
					lua_rawget(L, -2); // cls = module[name]

					// For ffi purpose
					lua_pushliteral(L, "__sizeof");
					lua_push(L, sizeof(typename _ArrayT::type));
					lua_rawset(L, -3);

					lua_pop(L, 1);
				}

				lua_pop(L, 1);
			}

			return true;
		}();
	}

	template<typename T, size_t ...Dims>
	int FixedSizeArrayBase<T, Dims...>::__len(lua_State* L) {
		lua_push(L, FixedSizeArrayBase<T, Dims...>::size);
		return 1;
	}

	template<typename T, size_t ...Dims>
	int FixedSizeArrayBase<T, Dims...>::__index(lua_State* L) {
		using _ArrayT = FixedSizeArray<T, Dims...>;

		auto vargc = lua_gettop(L);

		if (vargc == 2) {
			bool is_valid;
			auto self = lua_to(L, 1, static_cast<_ArrayT*>(nullptr), is_valid);
			if (!is_valid) {
				goto overload;
			}

			if (lua_type(L, 2) == LUA_TSTRING && std::strcmp(lua_tostring(L, 2), "__self") == 0) {
				lua_pushlightuserdata(L, &*(self->data));
				return 1;
			}

			auto index_holder = lua_to(L, 2, static_cast<size_t*>(nullptr), is_valid);
			if (!is_valid) {
				goto overload;
			}

			decltype(auto) index = extract_holder(index_holder, static_cast<size_t*>(nullptr));
			if (index >= _ArrayT::size) {
				luaL_error(L, "index %d is out of range. Expecting a number between 1 and %d.", index, _ArrayT::size - 1);
			}

			if constexpr (sizeof...(Dims) == 1) {
				if constexpr (is_usertype_v<T>) {
					lua_push(L, &self->operator[](index));
				} else {
					lua_push(L, self->operator[](index));
				}
			}
			else {
				lua_push(L, typename _ArrayT::value_type(self->operator[](index)));
			}

			return lua_gettop(L) - vargc;
		}
		overload:

		auto ret = try_mt__index(L);
		if (ret != 0) {
			return lua_gettop(L) - vargc;
		}

		return lua_missing_declaration(L);
	}

	template<typename T, size_t ...Dims>
	int FixedSizeArrayBase<T, Dims...>::__newindex(lua_State* L) {
		using _ArrayT = FixedSizeArray<T, Dims...>;

		auto vargc = lua_gettop(L);

		if (vargc < 2) {
			LUAL_MODULE_ERROR_RETURN(L, "index is undefined");
		}

		if (vargc < 3) {
			LUAL_MODULE_ERROR_RETURN(L, "new value is undefined");
		}

		if (vargc > 3) {
			LUAL_MODULE_ERROR_RETURN(L, "too many arguments");
		}

		bool is_valid;
		auto self = lua_to(L, 1, static_cast<_ArrayT*>(nullptr), is_valid);
		if (!is_valid) {
			return luaL_typeerror(L, 1, internal::GetTypeName<_ArrayT>());
		}

		auto index_holder = lua_to(L, 2, static_cast<size_t*>(nullptr), is_valid);
		if (!is_valid) {
			// set the value on the instance
			lua_pushvalue(L, 2); // push the key
			lua_pushvalue(L, 3); // push the value
			lua_rawset(L, 1);
			return lua_gettop(L) - vargc;
		}

		decltype(auto) index = extract_holder(index_holder, static_cast<size_t*>(nullptr));
		if (index >= _ArrayT::size) {
			luaL_error(L, "index %d is out of range. Expecting a number between 1 and %d.", index, _ArrayT::size - 1);
		}

		auto value_holder = lua_to(L, 3, static_cast<_ArrayT::value_type*>(nullptr), is_valid);
		if (!is_valid) {
			return luaL_typeerror(L, 3, internal::GetTypeName<typename _ArrayT::value_type>());
		}
		decltype(auto) value = extract_holder(value_holder, static_cast<_ArrayT::value_type*>(nullptr));

		self->assign(index, value);
		return lua_gettop(L) - vargc;
	}

	template<typename T, size_t... Dims>
	void lua_push_carray_table(lua_State* L, const FixedSizeArray<T, Dims...>& self) {
		using _ArrayT = FixedSizeArray<T, Dims...>;

		lua_newtable(L);
		int index = lua_gettop(L);
		for (int i = 0; i < _ArrayT::size; i++) {
			if constexpr (sizeof...(Dims) == 1) {
				lua_push(L, self[i]);
			}
			else {
				lua_push_carray_table(L, typename _ArrayT::value_type(const_cast<typename _ArrayT::pointer&>(self[i])));
			}
			lua_rawseti(L, index, i + 1);
		}
	}

	template<typename T, size_t ...Dims>
	int FixedSizeArrayBase<T, Dims...>::table(lua_State* L) {
		using _ArrayT = FixedSizeArray<T, Dims...>;

		auto vargc = lua_gettop(L);
		if (vargc != 1) {
			LUAL_MODULE_ERROR_RETURN(L, "too many arguments");
		}

		bool is_valid;
		auto self = lua_to(L, 1, static_cast<_ArrayT*>(nullptr), is_valid);
		if (!is_valid) {
			return luaL_typeerror(L, 1, internal::GetTypeName<_ArrayT>());
		}

		lua_push_carray_table(L, *self);
		return lua_gettop(L) - vargc;
	}

	template<typename T, size_t ...Dims>
	std::mutex usertype_info<FixedSizeArray<T, Dims...>>::mutex;

	template<typename T, size_t ...Dims>
	std::vector<const void*> usertype_info<FixedSizeArray<T, Dims...>>::metatable_pointers;

	template<typename T, size_t ...Dims>
	std::vector<int> usertype_info<FixedSizeArray<T, Dims...>>::metatable_refs;

	template<typename T, size_t ...Dims>
	const struct luaL_Reg usertype_info<FixedSizeArray<T, Dims...>>::methods[] = {
		{"__len", FixedSizeArray<T, Dims...>::__len},
		{"__index", FixedSizeArray<T, Dims...>::__index},
		{"__newindex", FixedSizeArray<T, Dims...>::__newindex},
		{"table", FixedSizeArray<T, Dims...>::table},
		{NULL, NULL} // Sentinel
	};

	template<typename T, size_t ...Dims>
	const struct luaL_Reg usertype_info<FixedSizeArray<T, Dims...>>::meta_methods[] = {
		{NULL, NULL} // Sentinel
	};

	template<typename T, size_t ...Dims>
	std::shared_ptr<FixedSizeArray<T, Dims...>> usertype_info<FixedSizeArray<T, Dims...>>::lua_userdata_to(lua_State* L, int index, bool& is_valid) {
		using _ArrayT = FixedSizeArray<T, Dims...>;
		_ArrayT::register_class(L);

		auto carray = testudata_metatable<_ArrayT>(L, index, is_valid);
		if (is_valid) {
			return carray;
		}

		if (lua_istable(L, index)) {
			if (index < 0) {
				index += lua_gettop(L) + 1;
			}

			auto size = lua_rawlen(L, index);
			is_valid = size == _ArrayT::size;
			if (!is_valid) {
				return carray;
			}

			carray = std::make_shared<_ArrayT>();

			for (auto i = 1; i <= size; ++i) {
				lua_pushnumber(L, i);
				lua_rawget(L, index);
				auto value_holder = lua_to(L, -1, static_cast<typename _ArrayT::value_type*>(nullptr), is_valid);
				lua_pop(L, 1);

				if (!is_valid) {
					break;
				}

				decltype(auto) value = extract_holder(value_holder, static_cast<typename _ArrayT::value_type*>(nullptr));
				carray->assign(i - 1, value);
			}

			return carray;
		}

		if constexpr (is_usertype_v<std::vector<typename _ArrayT::value_type>>) {
			if (!lua_islightuserdata(L, index) && lua_isuserdata(L, index)) {
				auto vec_holder = lua_to(L, index, static_cast<std::vector<typename _ArrayT::value_type>*>(nullptr), is_valid);
				if (is_valid) {
					decltype(auto) vec = extract_holder(vec_holder, static_cast<void**>(nullptr));

					is_valid = vec.size() == _ArrayT::size;
					if (!is_valid) {
						return carray;
					}

					carray = std::make_shared<_ArrayT>();

					auto i = 0;
					for (const auto& value : vec) {
						carray->assign(i++, value);
					}

					return carray;
				}
			}
		}

		{
			auto value_holder = lua_to(L, index, static_cast<void**>(nullptr), is_valid);
			if (is_valid) {
				decltype(auto) value = extract_holder(value_holder, static_cast<void**>(nullptr));
				return std::make_shared<_ArrayT>(*reinterpret_cast<typename _ArrayT::type*>(&value));
			}
		}

		return carray;
	}

	template<typename T, size_t ...Dims>
	inline std::shared_ptr<FixedSizeArray<T, Dims...>> lua_to(lua_State* L, int index, FixedSizeArray<T, Dims...>*, bool& is_valid) {
		return usertype_info<FixedSizeArray<T, Dims...>>::lua_userdata_to(L, index, is_valid);
	}

	template<typename T, size_t ...Dims>
	inline void lua_push(lua_State* L, FixedSizeArray<T, Dims...>&& array) {
		using _ArrayT = FixedSizeArray<T, Dims...>;
		_ArrayT::register_class(L);
		lua_push(L, std::make_shared<_ArrayT>(std::move(array)));
	}


	// ================================
	// c function
	// ================================

	template<typename T>
	void FFITypeTraitsBase<T>::lua_push(lua_State* L, void* arg) {
		if constexpr (is_usertype_v<T>) {
			lua_push(L, static_cast<T*>(arg));
		} else {
			lua_push(L, *static_cast<T*>(arg));
		}
	}

	template <class T, class U, class V>
	using enable_if_is_same_u_and_not_same_v_t = std::enable_if_t<std::is_same_v<T, U> && !std::is_same_v<T, V>>;

	template<typename T>
	struct FFITypeTraits<T*> : FFITypeTraitsBase<T*> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_pointer;
		}
	};

	template<typename T>
	struct FFITypeTraits<T&> : FFITypeTraitsBase<T&> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_pointer;
		}
	};

	template<typename T>
	struct FFITypeTraits<T[]> : FFITypeTraitsBase<T[]> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_pointer;
		}
	};

	template<typename T, std::size_t N>
	FFITypeTraits<T[N]>::FFITypeTraits() {
		for (std::size_t i = 0; i < N; ++i) {
			elements[i] = FFITypeTraits<T>::ffi_type_ptr();
		}

		elements[N] = nullptr;

		array_type.size = array_type.alignment = 0;
		array_type.type = FFI_TYPE_STRUCT;
		array_type.elements = elements;
	}

	template<typename T, std::size_t N>
	ffi_type* FFITypeTraits<T[N]>::ffi_type_ptr() {
		static FFITypeTraits<T[N]> type_trait;
		return &type_trait.array_type;
	}

	template<typename T>
	struct FFITypeTraits<T, enable_if_is_same_u_and_not_same_v_t<T, char, int8_t>> : FFITypeTraitsBase<T> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_schar;
		}
	};

	template<typename T>
	struct FFITypeTraits<T, enable_if_is_same_u_and_not_same_v_t<T, unsigned char, uint8_t>> : FFITypeTraitsBase<T> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_uchar;
		}
	};

	template<typename T>
	struct FFITypeTraits<T, enable_if_is_same_u_and_not_same_v_t<T, short, int16_t>> : FFITypeTraitsBase<T> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_sshort;
		}
	};

	template<typename T>
	struct FFITypeTraits<T, enable_if_is_same_u_and_not_same_v_t<T, unsigned short, uint16_t>> : FFITypeTraitsBase<T> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_ushort;
		}
	};

	template<typename T>
	struct FFITypeTraits<T, enable_if_is_same_u_and_not_same_v_t<T, int, int32_t>> : FFITypeTraitsBase<T> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_sint;
		}
	};

	template<typename T>
	struct FFITypeTraits<T, enable_if_is_same_u_and_not_same_v_t<T, unsigned int, uint32_t>> : FFITypeTraitsBase<T> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_uint;
		}
	};

	template<typename T>
	struct FFITypeTraits<T, enable_if_is_same_u_and_not_same_v_t<T, long, int64_t>> : FFITypeTraitsBase<T> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_slong;
		}
	};

	template<typename T>
	struct FFITypeTraits<T, enable_if_is_same_u_and_not_same_v_t<T, unsigned long, uint64_t>> : FFITypeTraitsBase<T> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_ulong;
		}
	};

	template<typename T>
	struct FFITypeTraits<T, std::enable_if_t<std::is_same_v<T, long double>>> : FFITypeTraitsBase<T> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_longdouble;
		}
	};

	template<>
	struct FFITypeTraits<void> : FFITypeTraitsBase<void> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_void;
		}
	};

	template<>
	struct FFITypeTraits<bool> : FFITypeTraitsBase<bool> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_uint8;
		}
	};

	template<>
	struct FFITypeTraits<int8_t> : FFITypeTraitsBase<int8_t> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_sint8;
		}
	};

	template<>
	struct FFITypeTraits<uint8_t> : FFITypeTraitsBase<uint8_t> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_uint8;
		}
	};

	template<>
	struct FFITypeTraits<int16_t> : FFITypeTraitsBase<int16_t> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_sint16;
		}
	};

	template<>
	struct FFITypeTraits<uint16_t> : FFITypeTraitsBase<uint16_t> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_uint16;
		}
	};

	template<>
	struct FFITypeTraits<int32_t> : FFITypeTraitsBase<int32_t> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_sint32;
		}
	};

	template<>
	struct FFITypeTraits<uint32_t> : FFITypeTraitsBase<uint32_t> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_uint32;
		}
	};

	template<>
	struct FFITypeTraits<int64_t> : FFITypeTraitsBase<int64_t> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_sint64;
		}
	};

	template<>
	struct FFITypeTraits<uint64_t> : FFITypeTraitsBase<uint64_t> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_uint64;
		}
	};

	template<typename T>
	struct FFITypeTraits<T, enable_if_is_same_u_and_not_same_v_t<T, long long, int64_t>> : FFITypeTraitsBase<T> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_sint64;
		}
	};

	template<typename T>
	struct FFITypeTraits<T, enable_if_is_same_u_and_not_same_v_t<T, unsigned long long, uint64_t>> : FFITypeTraitsBase<T> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_uint64;
		}
	};

	template<>
	struct FFITypeTraits<float> : FFITypeTraitsBase<float> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_float;
		}
	};

	template<>
	struct FFITypeTraits<double> : FFITypeTraitsBase<double> {
		static ffi_type* ffi_type_ptr() {
			return &ffi_type_double;
		}
	};

	template<typename R, typename... Args>
	CFunctionInvokerBase<R, Args...>::CFunctionInvokerBase(lua_State* L, int index, bool& is_valid) {
		auto fn = lua_to(L, index, static_cast<Function*>(nullptr), is_valid);
		if (!is_valid) {
			return;
		}

		this->fn.assign(L, fn);
		this->creator_gil_mutex = get_gil_mutex(L);
		this->creator_thread_id = std::this_thread::get_id();
		this->creator_gil = get_thread_gil(L, creator_gil_mutex);

		is_valid = false;

		/* Allocate closure and bound_function */
		closure = reinterpret_cast<ffi_closure*>(ffi_closure_alloc(sizeof(ffi_closure), &bound_function));
		if (!closure) {
			luaL_error(L, "Failed to allocate the closure");
			return;
		}

		const auto& nargs = Invoker::ArgCount;
		const auto& rtype = Invoker::ffi_return_type();
		const auto& atypes = Invoker::ffi_args_types();

		/* Initialize the cif */
		if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, nargs, rtype, atypes) != FFI_OK) {
			ffi_closure_free(closure);
			closure = nullptr;
			luaL_error(L, "Failed to initialize the cif");
			return;
		}

		/* Initialize the closure */
		if (ffi_prep_closure_loc(closure, &cif, &Invoker::function_binding, this, bound_function) != FFI_OK) {
			ffi_closure_free(closure);
			closure = nullptr;
			luaL_error(L, "Failed to initialize the cif");
			return;
		}

		is_valid = true;
	}

	template<typename R, typename... Args>
	CFunctionInvokerBase<R, Args...>::~CFunctionInvokerBase() {
		if (closure) {
			ffi_closure_free(closure);
		}
	}

	template<typename R, typename... Args>
	ffi_type* CFunctionInvokerBase<R, Args...>::ffi_return_type() {
		return FFITypeTraits<R>::ffi_type_ptr();
	}

	template<std::size_t I = 0, typename... _Ts>
	inline void set_ffi_args_types(ffi_type** args) {
		using _Tuple = typename std::tuple<_Ts...>;
		using T = std::tuple_element_t<I, _Tuple>;
		args[I] = FFITypeTraits<T>::ffi_type_ptr();

		if constexpr (I != sizeof...(_Ts) - 1) {
			set_ffi_args_types<I + 1, _Ts...>(args);
		}
	}

	template<typename R, typename... Args>
	ffi_type** CFunctionInvokerBase<R, Args...>::ffi_args_types() {
		if constexpr (Invoker::ArgCount == 0) {
			return nullptr;
		}
		else {
			/* Initialize the argument info vectors */
			static ffi_type* args[Invoker::ArgCount];
			static bool initialized = false;
			if (!initialized) {
				set_ffi_args_types<0, Args...>(args);
				initialized = true;
			}
			return args;
		}
	}

	template<std::size_t I = 0, typename... _Ts>
	inline void push_ffi_args(lua_State* L, void** args) {
		using _Tuple = typename std::tuple<_Ts...>;
		using T = std::tuple_element_t<I, _Tuple>;
		lua_push(L, *reinterpret_cast<T*>(args[I]));

		if constexpr (I != sizeof...(_Ts) - 1) {
			push_ffi_args<I + 1, _Ts...>(L, args);
		}
	}

	template<typename R, typename... Args>
	void CFunctionInvokerBase<R, Args...>::invoke(void* ret, void** args, void* user_data) {
		const auto& invoker = *reinterpret_cast<Invoker*>(user_data);
		lua_State* L = invoker.fn.L;

		lua_push(L, invoker.fn);

		if constexpr (Invoker::ArgCount != 0) {
			push_ffi_args<0, Args...>(L, args);
		}

		if constexpr (std::is_same_v<R, void>) {
			lua_call(L, Invoker::ArgCount, 0);
		}
		else {
			lua_call(L, Invoker::ArgCount, 1);
		}

		if constexpr (!std::is_same_v<R, void>) {
			// I did not find a way to keep reference to pointers without memory leak
			// Return the pointer hoping it will not be garbage collected
			if constexpr (std::is_same_v<R, const char*>) {
				bool is_valid = lua_type(L, -1) == LUA_TSTRING;
				if (!is_valid) {
					luaL_typeerror(L, -1, internal::GetTypeName<R>());
				}

				size_t len;
				*reinterpret_cast<R*>(ret) = lua_tolstring(L, -1, &len);
				lua_pop(L, 1);
			}
			else if constexpr (std::is_pointer_v<R>) {
				bool is_valid = lua_islightuserdata(L, -1);
				if (!is_valid) {
					luaL_typeerror(L, -1, internal::GetTypeName<R>());
				}

				*reinterpret_cast<R*>(ret) = static_cast<R>(lua_touserdata(L, -1));
				lua_pop(L, 1);
			}
			else {
				bool is_valid;
				auto value_holder = lua_to(L, -1, static_cast<R*>(nullptr), is_valid);
				if (!is_valid) {
					luaL_typeerror(L, -1, internal::GetTypeName<R>());
				}

				lua_pop(L, 1);
				decltype(auto) value = extract_holder(value_holder, static_cast<R*>(nullptr));
				*reinterpret_cast<R*>(ret) = value;
			}
		}
	}

	template<typename R, typename... Args>
	void CFunctionInvokerBase<R, Args...>::function_binding(ffi_cif* cif, void* ret, void** args, void* user_data) {
		decltype(auto) invoker = *reinterpret_cast<Invoker*>(user_data);
		GilLock lock(invoker.fn.L, invoker.creator_gil_mutex, invoker.creator_thread_id, invoker.creator_gil);
		invoke(ret, args, user_data);
	}

	template<typename Invoker>
	int CFunctionInvoker_destroy(lua_State* L) {
		auto invoker_ptr = static_cast<std::shared_ptr<Invoker>*>(lua_touserdata(L, 1));
		invoker_ptr->~shared_ptr();
		return 0;
	}

	template<typename R, typename... Args>
	typename CFunctionInvoker<R(Args...)>::Pointer lua_to(lua_State* L, int index, R(**)(Args...), bool& is_valid) {
		using Invoker = CFunctionInvoker<R(Args...)>;
		std::shared_ptr<Invoker>* invoker_ptr;

		if (lua_isnil(L, index)) {
			return static_cast<Invoker::Pointer>(nullptr);
		}

		if (lua_islightuserdata(L, index)) {
			is_valid = true;
			return reinterpret_cast<Invoker::Pointer>(lua_touserdata(L, index));
		}

		const auto fn_lua_ptr = lua_topointer(L, index);

		char fn_key[64];
		const int fn_key_len = snprintf(fn_key, 64, LUA_MODULE_NAME_STR "_CFunctionInvoker_%p",  fn_lua_ptr);

		lua_pushlstring(L, fn_key, fn_key_len);
		lua_rawget(L, LUA_REGISTRYINDEX);

		if (lua_isnil(L, -1)) {
			// remove nil
			lua_pop(L, 1);

			// create an save invoker in the state
			lua_pushlstring(L, fn_key, fn_key_len);

			invoker_ptr = static_cast<std::shared_ptr<Invoker>*>(lua_newuserdata(L, sizeof(std::shared_ptr<Invoker>)));
			new(invoker_ptr) std::shared_ptr<Invoker>(std::make_shared<Invoker>(L, index, is_valid));

			if (!is_valid) {
				// remove pushed key
				lua_pop(L, 1);

				// destroy created invoker
				invoker_ptr->~shared_ptr();
				return nullptr;
			}

			lua_newtable(L);
			lua_pushstring(L, "__gc");
			lua_pushcfunction(L, CFunctionInvoker_destroy<Invoker>);
			lua_rawset(L, -3);

			lua_setmetatable(L, -2);
			lua_rawset(L, LUA_REGISTRYINDEX);
		} else {
			is_valid = true;
			invoker_ptr = static_cast<std::shared_ptr<Invoker>*>(lua_touserdata(L, -1));
			lua_pop(L, 1);
		}

		return reinterpret_cast<Invoker::Pointer>(invoker_ptr->get()->bound_function);;
	}

	// ================================
	// variadic
	// ================================

	namespace detail {
		union FFIStorage {
			bool bval;
			lua_Integer ival;
			lua_Number nval;
			const char* c_str;
			void* ptr;
		};
	}

	template<typename R, typename... Args, typename... Args_>
	R ffi_call_variadic(lua_State* L, size_t args_offset, R(*fn)(Args..., ...), Args_&&... args) {
		unsigned int nfixedargs = sizeof...(Args);
		unsigned int ntotalargs = lua_gettop(L) - args_offset;
		unsigned int vargc = ntotalargs - nfixedargs;

		std::vector<ffi_type*> argtypes(ntotalargs);
		std::vector<void*> argvalues(ntotalargs);
		std::vector<detail::FFIStorage> vargv(vargc);

		/* Initialize the fixed arguments info vectors */
		int nargs = 0;
		([&] {
			argtypes[nargs] = FFITypeTraits<Args>::ffi_type_ptr();
			argvalues[nargs] = &args;
			nargs++;
			} (), ...);

		/* Initialize the variadic arguments info vectors */
		for (int index = nfixedargs + args_offset + 1, i = 0; index < ntotalargs + args_offset + 1; index++, i++, nargs++) {
			argvalues[nargs] = &vargv[i];

			switch (lua_type(L, index)) {
			case LUA_TBOOLEAN:
				argtypes[nargs] = &ffi_type_uint8;
				vargv[i].bval = lua_toboolean(L, index);
				break;
			case LUA_TNUMBER:
#if LUA_VERSION_NUM >= 503
				// Lua 5.3 and greater check for numeric precision
				// https://en.cppreference.com/w/cpp/types/numeric_limits
				if (lua_isinteger(L, index)) {
					argtypes[nargs] = FFITypeTraits<lua_Integer>::ffi_type_ptr();
					vargv[i].ival = lua_tointeger(L, index);
					break;
				}
#endif
				argtypes[nargs] = FFITypeTraits<lua_Number>::ffi_type_ptr();
				vargv[i].nval = lua_tonumber(L, index);
				break;
			case LUA_TNIL:
				argtypes[nargs] = &ffi_type_pointer;
				vargv[i].ptr = nullptr;
				break;
			case LUA_TSTRING:
				argtypes[nargs] = &ffi_type_pointer;
				vargv[i].c_str = lua_tostring(L, index);
				break;
			case LUA_TLIGHTUSERDATA:
				argtypes[nargs] = &ffi_type_pointer;
				vargv[i].ptr = lua_touserdata(L, index);
				break;
			default:
				luaL_typeerror(L, index, "bool, number, string, lightuserdata, nil");
				break;
			}
		}

		ffi_type* rtype = FFITypeTraits<R>::ffi_type_ptr();
		ffi_cif cif;
		ffi_arg rvalue;

		/* Initialize the cif */
		if (ffi_prep_cif_var(&cif, FFI_DEFAULT_ABI, nfixedargs, ntotalargs, rtype, argtypes.data()) == FFI_OK) {
			ffi_call(&cif, reinterpret_cast<void(*)()>(fn), &rvalue, argvalues.data());
			/* rvalue now holds the result of the call to fn */
		}
		else {
			luaL_error(L, "Failed to initialize the cif");
		}

		if constexpr (!std::is_same_v<R, void>) {
			return *reinterpret_cast<R*>(&rvalue);
		}
	}
}

namespace LUA_MODULE_NAME {
	void register_extensions(lua_State* L);
}
