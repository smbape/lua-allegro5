#pragma once

#include <lua_bridge_common.hdr.hpp>
#include <ffi.h>

namespace LUA_MODULE_NAME {
	// ================================
	// bool
	// ================================

	template<typename T>
	struct lua_to_custom_bridge<T, std::enable_if_t<std::is_same_v<T, bool>>> {
		static constexpr bool value = true;
		static T lua_to(lua_State* L, int index, bool& is_valid);
	};

	// ================================
	// std::integral
	// ================================

	template<typename T>
	struct lua_to_custom_bridge<T, std::enable_if_t<std::is_integral_v<T> && !std::is_same_v<bool, std::decay_t<T>>>> {
		static constexpr bool value = true;
		static T lua_to(lua_State* L, int index, bool& is_valid);
	};


	// ================================
	// std::floating_point
	// ================================

	template<typename T>
	struct lua_to_custom_bridge<T, std::enable_if_t<std::is_floating_point_v<T>>> {
		static constexpr bool value = true;
		static T lua_to(lua_State* L, int index, bool& is_valid);
	};


	// ================================
	// void*
	// ================================

	template<typename T>
	struct lua_to_custom_bridge<T, std::enable_if_t<std::is_same_v<T, void*>>> {
		static constexpr bool value = true;
		static T lua_to(lua_State* L, int index, bool& is_valid);
	};

	// ================================
	// T*
	// ================================

	template<typename T>
	struct lua_to_custom_bridge<T, std::enable_if_t<is_usertype_pointer_v<T>>> {
		static constexpr bool value = true;
		static T lua_to(lua_State* L, int index, bool& is_valid);
	};


	// ================================
	// fixed-size array
	// ================================

	// https://stackoverflow.com/questions/7058098/variadic-templates-multidimensional-array-container

	template<typename T, size_t ...Dims>
	struct FixedSizeArrayTraits;

	template<typename T, size_t _Size>
	struct FixedSizeArrayTraits<T, _Size> {
		using type = T[_Size];
		static constexpr size_t size = _Size;
	};

	template<typename T, size_t _Size, size_t ...Dims>
	struct FixedSizeArrayTraits<T, _Size, Dims...> {
		using pointer = typename FixedSizeArrayTraits<T, Dims...>::type;
		using type = pointer[_Size];
		static constexpr size_t size = _Size;
	};

	template<typename T, size_t ...Dims>
	struct FixedSizeArrayBase {
		using type = typename FixedSizeArrayTraits<T, Dims...>::type;
		static constexpr size_t size = FixedSizeArrayTraits<T, Dims...>::size;

		static void register_class(lua_State* L);
		static int __len(lua_State* L);
		static int __index(lua_State* L);
		static int __newindex(lua_State* L);
		static int table(lua_State* L);

		FixedSizeArrayBase() : data(values) {}
		FixedSizeArrayBase(type& data) : data(data) {}
		virtual ~FixedSizeArrayBase() = default;

		// Implicit conversions
		operator type& () {
			return data;
		}
		operator const type& () const {
			return data;
		}

		type values;
		type& data;
	};

	template<typename T, size_t ...Dims>
	struct FixedSizeArray;

	template<typename T, size_t _Size>
	struct FixedSizeArray<T, _Size> : FixedSizeArrayBase<T, _Size> {
		using Base = FixedSizeArrayBase<T, _Size>;
		using Base::FixedSizeArrayBase;
		using value_type = T;

		T& operator[](size_t i) {
			return this->data[i];
		}

		const T& operator[](size_t i) const {
			return this->data[i];
		}

		void assign(size_t i, const T& value) {
			this->data[i] = value;
		}
	};

	template<typename T, size_t _Size, size_t ...Dims>
	struct FixedSizeArray<T, _Size, Dims...> : FixedSizeArrayBase<T, _Size, Dims...> {
		using Base = FixedSizeArrayBase<T, _Size, Dims...>;
		using Base::FixedSizeArrayBase;
		using value_type = FixedSizeArray<T, Dims...>;

		using pointer = typename FixedSizeArrayTraits<T, _Size, Dims...>::pointer;

		pointer& operator[](size_t i) {
			return this->data[i];
		}

		const pointer& operator[](size_t i) const {
			return this->data[i];
		}

		void assign(size_t i, const pointer& value) {
			std::memcpy(this->data[i], value, sizeof(pointer));
		}
	};

	template<typename T, size_t ...Dims>
	struct is_usertype<FixedSizeArray<T, Dims...>> : std::true_type {};

	template<typename T, size_t ...Dims>
	struct usertype_info<FixedSizeArray<T, Dims...>> {
		static std::mutex mutex;
		static std::vector<const void*> metatable_pointers;
		static std::vector<int> metatable_refs;
		static const struct luaL_Reg methods[];
		static const struct luaL_Reg meta_methods[];
		static std::shared_ptr<FixedSizeArray<T, Dims...>> lua_userdata_to(lua_State* L, int index, bool& is_valid);
	};

	template<typename T, std::size_t ...N>
	struct expand_all_extents {
		using type = std::conditional_t<(sizeof...(N) > 0), FixedSizeArray<T, N...>, T>;
	};

	template<typename T, std::size_t N1, std::size_t ...N2>
	struct expand_all_extents<T[N1], N2...> {
		using type = typename expand_all_extents<T, N2..., N1>::type;
	};

	template<typename T>
	struct expand_all_extents<T[]> {
		using type = typename expand_all_extents<T>::type*;
	};

	template<typename T, std::size_t N>
	struct expand_all_extents<T[N]> {
		using type = typename expand_all_extents<T, N>::type;
	};

	template<typename T>
	using expand_all_extents_t = typename expand_all_extents<T>::type;

	template<typename T, size_t ...Dims>
	inline std::shared_ptr<FixedSizeArray<T, Dims...>> lua_to(lua_State* L, int index, FixedSizeArray<T, Dims...>*, bool& is_valid);

	template<typename T, size_t ...Dims>
	inline void lua_push(lua_State* L, FixedSizeArray<T, Dims...>&& array);


	// ================================
	// c function
	// ================================
	// https://en.cppreference.com/w/cpp/language/type_alias.html
	// template<typename R, typename... Args>
	// using FunctionPointer = R(*)(Args...);

	// template<typename R, typename... Args>
	// inline FunctionPointer<R, Args...> lua_to(lua_State* L, int index, FunctionPointer<R, Args...>*, bool& is_valid);

	// https://stackoverflow.com/questions/997821/how-to-make-a-function-return-a-pointer-to-a-function-c#answer-55743513
	// template<typename R, typename... Args>
	// inline R (*lua_to(lua_State* L, int index, R (**)(Args...), bool& is_valid)) (Args...);

	// https://en.cppreference.com/w/cpp/utility/functional/function.html
	// https://devblogs.microsoft.com/oldnewthing/20200713-00/?p=103978
	template<typename>
	struct CFunctionInvoker;

	template<typename R, typename... Args>
	struct CFunctionInvoker<R(Args...)>;

	template<typename R>
	struct CFunctionInvoker<R()>;

	template<typename R, typename... Args>
	struct CFunctionInvokerBase {
		using RetType = R;
		using ArgTypes = std::tuple<Args...>;
		static constexpr std::size_t ArgCount = sizeof...(Args);
		using Invoker = CFunctionInvoker<R(Args...)>;

		static ffi_type* ffi_return_type();
		static ffi_type** ffi_args_types();
		static void invoke(void* ret, void** args, void* user_data);
		static void function_binding(ffi_cif* cif, void* ret, void** args, void* user_data);

		CFunctionInvokerBase() = default;

		CFunctionInvokerBase(lua_State* L, int index, bool& is_valid);

		virtual ~CFunctionInvokerBase();

		Function fn;
		std::shared_ptr<std::mutex> creator_gil_mutex;
		std::thread::id creator_thread_id;
		std::shared_ptr<std::unique_lock<std::mutex>> creator_gil;
		ffi_closure* closure = nullptr;
		ffi_cif cif;
		void* bound_function = nullptr;
	};

	template<typename R, typename... Args>
	struct CFunctionInvoker<R(Args...)> : CFunctionInvokerBase<R, Args...> {
		using Base = CFunctionInvokerBase<R, Args...>;
		using Base::CFunctionInvokerBase;
		using Pointer = R(*)(Args...);

		template<std::size_t N>
		using NthArg = std::tuple_element_t<N, typename Base::ArgTypes>;
		using FirstArg = NthArg<0>;
		using LastArg = NthArg<Base::ArgCount - 1>;
	};

	template<typename R>
	struct CFunctionInvoker<R()> : CFunctionInvokerBase<R> {
		using Base = CFunctionInvokerBase<R>;
		using Base::CFunctionInvokerBase;
		using Pointer = R(*)();
	};

	template<typename R, typename... Args>
	typename CFunctionInvoker<R(Args...)>::Pointer lua_to(lua_State* L, int index, R(**)(Args...), bool& is_valid);

	template<typename T>
	struct FFITypeTraitsBase {
		static void lua_push(lua_State* L, void* arg);
	};

	// https://stackoverflow.com/questions/20895184/identical-template-for-many-functions/20898554#20898554
	template<typename T, typename Enabled = void>
	struct FFITypeTraits;

	template<typename T, std::size_t N>
	struct FFITypeTraits<T[N]> : FFITypeTraitsBase<T[N]> {
		static ffi_type* ffi_type_ptr();

		FFITypeTraits();
		~FFITypeTraits() = default;

		ffi_type *elements[N + 1];
		ffi_type array_type;
	};

	struct FFIArgExtractor {
		void* (*extract) (lua_State* L, int index, bool& is_valid) = nullptr;
		void (*push) (lua_State* L, void* arg) = nullptr;
		void (*copy) (void** dst, void* src) = nullptr;
		void (*destroy) (void* ptr) = nullptr;
		ffi_type* ffi_type_ptr = nullptr;
	};

	void register_extractors();
	void register_extractor(const std::string& key, const FFIArgExtractor& extractor);
	FFIArgExtractor* get_extractor(const std::string& key);

	// ================================
	// variadic
	// ================================
	template<typename R, typename... Args, typename... Args_>
	R ffi_call_variadic(lua_State* L, size_t args_offset, R(*fn)(Args..., ...), Args_&&... args);
}
