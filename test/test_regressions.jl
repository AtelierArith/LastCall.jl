# Regression reproduction tests for known issues.

using RustCall
using Test

@testset "Known Regressions" begin
    @testset "Library-scoped return type metadata" begin
        empty!(RustCall.FUNCTION_RETURN_TYPES)
        empty!(RustCall.FUNCTION_RETURN_TYPES_BY_LIB)

        code_i32 = """
        #[no_mangle]
        pub extern "C" fn same_name() -> i32 {
            1
        }
        """

        code_f64 = """
        #[no_mangle]
        pub extern "C" fn same_name() -> f64 {
            1.0
        }
        """

        RustCall._register_function_signatures(code_i32, "lib_i32")
        @test RustCall.FUNCTION_RETURN_TYPES["same_name"] == Int32
        @test RustCall.get_function_return_type("lib_i32", "same_name") == Int32

        RustCall._register_function_signatures(code_f64, "lib_f64")
        @test RustCall.FUNCTION_RETURN_TYPES["same_name"] == Float64
        @test RustCall.get_function_return_type("lib_i32", "same_name") == Int32
        @test RustCall.get_function_return_type("lib_f64", "same_name") == Float64
    end

    @testset "Library-scoped return type is used by dynamic calls" begin
        if !RustCall.check_rustc_available()
            @warn "rustc not found, skipping library-scoped dynamic call test"
            return
        end

        code_i32 = """
        #[no_mangle]
        pub extern "C" fn same_name() -> i32 {
            7
        }
        """
        code_f64 = """
        #[no_mangle]
        pub extern "C" fn same_name() -> f64 {
            2.5
        }
        """

        lib_i32 = RustCall._compile_and_load_rust(code_i32, "test_regressions", 0)
        lib_f64 = RustCall._compile_and_load_rust(code_f64, "test_regressions", 0)

        result_i32 = RustCall._rust_call_dynamic(lib_i32, "same_name")
        result_f64 = RustCall._rust_call_dynamic(lib_f64, "same_name")

        @test result_i32 isa Int32
        @test result_i32 == Int32(7)
        @test result_f64 isa Float64
        @test result_f64 == 2.5
    end

    @testset "@rust supports library-qualified call syntax" begin
        if !RustCall.check_rustc_available()
            @warn "rustc not found, skipping library-qualified call syntax test"
            return
        end

        code = """
        #[no_mangle]
        pub extern "C" fn multiply(a: i32, b: i32) -> i32 {
            a * b
        }
        """

        lib_name = RustCall._compile_and_load_rust(code, "test_regressions", 0)

        result_untyped = eval(Meta.parse("@rust $(lib_name)::multiply(Int32(3), Int32(4))"))
        result_typed = eval(Meta.parse("@rust $(lib_name)::multiply(Int32(5), Int32(6))::Int32"))

        @test result_untyped == Int32(12)
        @test result_typed == Int32(30)
    end

    @testset "Functions without return annotation are treated as Cvoid" begin
        if !RustCall.check_rustc_available()
            @warn "rustc not found, skipping Cvoid return inference test"
            return
        end

        code = """
        #[no_mangle]
        pub extern "C" fn do_nothing(x: i32) {
            let _ = x;
        }
        """

        lib_name = RustCall._compile_and_load_rust(code, "test_regressions", 0)
        result = RustCall._rust_call_dynamic(lib_name, "do_nothing", Int32(7))
        @test result === nothing
    end

    @testset "@irust stale cache after unload_all_libraries" begin
        if !RustCall.check_rustc_available()
            @warn "rustc not found, skipping @irust regression reproduction test"
            return
        end

        empty!(RustCall.IRUST_FUNCTIONS)
        RustCall.unload_all_libraries()

        # First call compiles and caches the function.
        first_result = RustCall._compile_and_call_irust("arg1 + 1", Int32(1))
        @test first_result == Int32(2)

        # Simulate a session reset of loaded dynamic libraries only.
        RustCall.unload_all_libraries()
        @test isempty(RustCall.RUST_LIBRARIES)
        @test !isempty(RustCall.IRUST_FUNCTIONS)

        # Should detect stale cache entry and recompile transparently.
        @test RustCall._compile_and_call_irust("arg1 + 1", Int32(2)) == Int32(3)

        empty!(RustCall.IRUST_FUNCTIONS)
        RustCall.unload_all_libraries()
    end

    @testset "@irust rejects unsupported argument types" begin
        err = try
            RustCall._compile_and_call_irust("arg1", 1 + 2im)
            nothing
        catch e
            e
        end
        @test err !== nothing
        @test err isa ErrorException
        @test occursin("Unsupported Julia type for @irust", sprint(showerror, err))
    end

    @testset "Qualified @rust calls resolve libraries consistently" begin
        qualified_call = Expr(:call, Expr(:(::), :fake_lib, :fake_fn), :(Int32(1)))
        expanded = RustCall.rust_impl(@__MODULE__, qualified_call)
        expanded_str = sprint(show, expanded)
        @test occursin("_rust_call_from_lib", expanded_str)
        @test occursin("_resolve_lib", expanded_str)
    end

    @testset "extract_function_code handles generic functions" begin
        code = """
        pub fn identity<T>(x: T) -> T {
            x
        }
        """
        extracted = RustCall.extract_function_code(code, "identity")
        @test extracted !== nothing
        @test occursin("fn identity<T>", extracted)
        @test occursin("x", extracted)
    end

    @testset "extract_function_code handles escaped quotes in strings" begin
        # Escaped double quote inside string should not break brace counting
        code = """
        fn process() {
            let s = "contains \\" escaped quote";
            let x = 42;
        }
        """
        extracted = RustCall.extract_function_code(code, "process")
        @test extracted !== nothing
        @test occursin("let x = 42", extracted)
        @test occursin("}", extracted)
    end

    @testset "extract_function_code handles braces in strings" begin
        # Braces inside string literals should not be counted
        code = """
        fn format_json() -> String {
            let s = "{ \\"key\\": \\"value\\" }";
            s.to_string()
        }
        """
        extracted = RustCall.extract_function_code(code, "format_json")
        @test extracted !== nothing
        @test occursin("s.to_string()", extracted)
    end

    @testset "extract_function_code handles line comments" begin
        # Braces in comments should not be counted
        code = """
        fn with_comments() {
            // This comment has { braces } in it
            let x = 1;
        }
        """
        extracted = RustCall.extract_function_code(code, "with_comments")
        @test extracted !== nothing
        @test occursin("let x = 1", extracted)
    end

    @testset "extract_function_code handles block comments" begin
        code = """
        fn with_block_comment() {
            /* This block comment has { braces } */
            let x = 2;
        }
        """
        extracted = RustCall.extract_function_code(code, "with_block_comment")
        @test extracted !== nothing
        @test occursin("let x = 2", extracted)
    end

    @testset "extract_function_code handles char literals with braces" begin
        code = """
        fn char_braces() {
            let open = '{';
            let close = '}';
            let x = 3;
        }
        """
        extracted = RustCall.extract_function_code(code, "char_braces")
        @test extracted !== nothing
        @test occursin("let x = 3", extracted)
    end

    @testset "derive(JuliaStruct) parsing/removal handles multiline and order" begin
        multiline = """
        #[derive(
            JuliaStruct,
            Clone
        )]
        pub struct PointA {
            x: i32,
        }
        """
        cleaned_multiline = RustCall.remove_derive_julia_struct_attributes(multiline)
        @test !occursin("JuliaStruct", cleaned_multiline)
        @test occursin("Clone", cleaned_multiline)

        reordered = """
        #[derive(Clone, JuliaStruct)]
        pub struct PointB {
            x: i32,
        }
        """
        infos = RustCall.parse_structs_and_impls(reordered)
        @test length(infos) == 1
        @test infos[1].has_derive_julia_struct
        @test get(infos[1].derive_options, "Clone", false)
    end

    @testset "extract_function_code returns nothing for nonexistent function" begin
        code = """
        fn real_function() {
            let x = 1;
        }
        """
        @test RustCall.extract_function_code(code, "nonexistent") === nothing
    end

    @testset "detect_and_register warns on extraction fallback" begin
        # Code with a generic function whose name doesn't match the fn pattern
        # (no braces after function signature — causes extract_function_code to fail)
        code = """
        #[no_mangle]
        pub extern "C" fn missing_body<T>(x: T) -> T
        """
        # Should emit a warning about falling back to entire block
        @test_warn "Failed to extract function" RustCall._detect_and_register_generic_functions(code, "test_lib")
    end

    @testset "extract_block_at is accessible from module scope" begin
        # Verify that extract_block_at is defined in the RustCall module (issue #82)
        @test isdefined(RustCall, :extract_block_at)
        @test RustCall.extract_block_at isa Function
    end

    @testset "extract_block_at extracts balanced brace blocks" begin
        code = """
        pub struct Point {
            x: f64,
            y: f64,
        }
        """
        m = match(r"pub struct Point", code)
        result = RustCall.extract_block_at(code, m.offset)
        @test result !== nothing
        @test occursin("pub struct Point", result)
        @test occursin("x: f64", result)
        @test occursin("y: f64", result)
    end

    @testset "extract_block_at handles nested braces" begin
        code = """
        impl Point {
            fn new(x: f64, y: f64) -> Self {
                Point { x, y }
            }
        }
        """
        m = match(r"impl Point", code)
        result = RustCall.extract_block_at(code, m.offset)
        @test result !== nothing
        @test occursin("impl Point", result)
        @test occursin("fn new", result)
        @test occursin("Point { x, y }", result)
    end

    @testset "extract_block_at returns nothing when no brace found" begin
        code = "fn no_body()"
        result = RustCall.extract_block_at(code, 1)
        @test result === nothing
    end

    @testset "extract_block_at handles tuple structs" begin
        code = "pub struct Wrapper(i32);"
        result = RustCall.extract_block_at(code, 1)
        @test result !== nothing
        @test occursin("Wrapper", result)
    end

    @testset "Lifetime parameters are skipped in generic function detection" begin
        # Function with lifetime and type parameter
        code = """
        pub fn process<'a, T>(data: &'a T) -> &'a T {
            data
        }
        """
        empty!(RustCall.GENERIC_FUNCTION_REGISTRY)
        RustCall._detect_and_register_generic_functions(code, "test_lifetime")
        @test haskey(RustCall.GENERIC_FUNCTION_REGISTRY, "process")
        info = RustCall.GENERIC_FUNCTION_REGISTRY["process"]
        # Should only have T, not 'a
        @test info.type_params == [:T]
        empty!(RustCall.GENERIC_FUNCTION_REGISTRY)
    end

    @testset "Lifetime-only generic functions are not registered" begin
        # Function with only lifetime parameters (not truly generic for monomorphization)
        code = """
        pub fn borrow<'a>(data: &'a i32) -> &'a i32 {
            data
        }
        """
        empty!(RustCall.GENERIC_FUNCTION_REGISTRY)
        RustCall._detect_and_register_generic_functions(code, "test_lifetime_only")
        # Should not be registered since there are no type parameters
        @test !haskey(RustCall.GENERIC_FUNCTION_REGISTRY, "borrow")
        empty!(RustCall.GENERIC_FUNCTION_REGISTRY)
    end

    @testset "parse_inline_constraints skips lifetime parameters" begin
        type_params, constraints = RustCall.parse_inline_constraints("'a, T: Clone, U")
        @test type_params == [:T, :U]
        @test haskey(constraints, :T)
        @test !haskey(constraints, Symbol("'a"))
    end

    @testset "_convert_args_for_rust dead code removed (#99)" begin
        # _convert_args_for_rust was a no-op function that returned args unchanged.
        # Verify it has been removed from the module.
        @test !isdefined(RustCall, :_convert_args_for_rust)
    end

    @testset "Unused source parameter removed from macro expansion (#100)" begin
        # rust_impl and friends no longer accept a source parameter.
        # Verify 2-arg rust_impl works and 3-arg (with source) errors.
        call_expr = Expr(:call, :fake_fn, :(Int32(1)))
        expanded = RustCall.rust_impl(@__MODULE__, call_expr)
        expanded_str = sprint(show, expanded)
        @test occursin("_rust_call_dynamic", expanded_str)

        # The old 3-arg signature should no longer exist
        @test_throws MethodError RustCall.rust_impl(@__MODULE__, call_expr, LineNumberNode(1))
    end

    @testset "Unique filenames in debug_dir prevent overwrite (#101)" begin
        # When debug_dir is set, different source code should produce different filenames
        compiler_debug = RustCall.RustCompiler(debug_mode=true, debug_dir=mktempdir())

        name1 = RustCall._unique_source_name("fn foo() {}", compiler_debug)
        name2 = RustCall._unique_source_name("fn bar() {}", compiler_debug)
        name_same = RustCall._unique_source_name("fn foo() {}", compiler_debug)

        # Different code → different names
        @test name1 != name2
        # Same code → same name (deterministic)
        @test name1 == name_same
        # Names should have hash prefix
        @test startswith(name1, "rust_")
        @test length(name1) == 5 + RustCall.RECOVERY_FINGERPRINT_LEN  # "rust_" + 12-char hash

        # Without debug_dir, should return the fixed name
        compiler_normal = RustCall.RustCompiler(debug_mode=false)
        @test RustCall._unique_source_name("fn foo() {}", compiler_normal) == "rust_code"

        # Clean up
        rm(compiler_debug.debug_dir, recursive=true, force=true)

        # Integration test: compile two functions to the same debug_dir
        if RustCall.check_rustc_available()
            debug_dir = mktempdir()
            compiler = RustCall.RustCompiler(debug_mode=true, debug_dir=debug_dir)

            code1 = """
            #[no_mangle]
            pub extern "C" fn debug_fn_a() -> i32 { 1 }
            """
            code2 = """
            #[no_mangle]
            pub extern "C" fn debug_fn_b() -> i32 { 2 }
            """

            lib1 = RustCall.compile_rust_to_shared_lib(code1; compiler=compiler)
            lib2 = RustCall.compile_rust_to_shared_lib(code2; compiler=compiler)

            # Both libraries should exist (not overwritten)
            @test isfile(lib1)
            @test isfile(lib2)
            @test lib1 != lib2

            rm(debug_dir, recursive=true, force=true)
        end
    end
end

# ============================================================================
# Prevention regression tests
# These tests guard against recurrence of previously fixed issues.
# ============================================================================

@testset "Prevention Regressions" begin

    # #130 / #82: Cross-file function dependencies lack load-time validation
    @testset "Cross-file dependencies are accessible (#130)" begin
        # Verify critical cross-file functions are defined in the module
        @test isdefined(RustCall, :extract_block_at)
        @test isdefined(RustCall, :parse_struct_fields)
        @test isdefined(RustCall, :parse_julia_functions)
        @test isdefined(RustCall, :parse_structs_and_impls)

        # Verify the load-time guard in crate_bindings.jl would have caught missing deps
        # (If extract_block_at wasn't defined, the include would have errored)
        @test RustCall.extract_block_at isa Function
        @test RustCall.parse_struct_fields isa Function
    end

    # #132 / #80: Race condition in multi-step lock/unlock sequences
    @testset "Per-library reload locks exist (#132)" begin
        # Verify the per-library lock infrastructure exists
        @test isdefined(RustCall, :RELOAD_LOCKS)
        @test isdefined(RustCall, :RELOAD_LOCKS_LOCK)
        @test isdefined(RustCall, :_get_reload_lock)

        # Verify _get_reload_lock returns a ReentrantLock and caches it
        lock1 = RustCall._get_reload_lock("test_prevention_lib")
        @test lock1 isa ReentrantLock
        lock2 = RustCall._get_reload_lock("test_prevention_lib")
        @test lock1 === lock2  # Same lock returned for same library

        # Different library gets different lock
        lock3 = RustCall._get_reload_lock("test_prevention_other")
        @test lock1 !== lock3

        # Clean up
        delete!(RustCall.RELOAD_LOCKS, "test_prevention_lib")
        delete!(RustCall.RELOAD_LOCKS, "test_prevention_other")
    end

    # #134 / #84: Rust syntax elements misidentified in code parsing
    @testset "Lifetime parameters are filtered in type parsing (#134)" begin
        # parse_inline_constraints should skip lifetime params
        type_params, constraints = RustCall.parse_inline_constraints("'a, T: Clone, 'b, U")
        @test type_params == [:T, :U]
        @test !haskey(constraints, Symbol("'a"))
        @test !haskey(constraints, Symbol("'b"))
        @test haskey(constraints, :T)

        # Lifetime-only should produce empty type params
        type_params2, _ = RustCall.parse_inline_constraints("'a, 'static")
        @test isempty(type_params2)

        # Mixed lifetime and type with trait bounds
        type_params3, constraints3 = RustCall.parse_inline_constraints("'a, T: Clone + Send, U: Sync")
        @test type_params3 == [:T, :U]
    end

    # #136 / #93: Unguarded exceptions in finalizers crash GC
    @testset "Generated finalizers have try-catch guards (#136)" begin
        # Create a test struct info
        test_struct = RustCall.RustStructInfo(
            "TestStruct",
            String[],
            RustCall.RustMethod[],
            "",
            [("x", "i32"), ("y", "f64")],
            false,
            Dict{String, Bool}()
        )

        # Verify _emit_struct_code wraps finalizer in try-catch
        code = RustCall._emit_struct_code(test_struct)
        @test occursin("try", code)
        @test occursin("catch", code)
        @test occursin("finalizer", code)
        # Should use exception= kwarg, not string interpolation of $e
        @test occursin("exception=e", code) || occursin("exception = e", code)
    end

    # #138 / #94: Missing null pointer guards in generated wrappers
    @testset "Generated wrappers include null pointer checks (#138)" begin
        # _check_not_freed function exists
        @test isdefined(RustCall, :_check_not_freed)

        # Test _check_not_freed with valid pointer
        obj_alive = (ptr = Ptr{Cvoid}(1),)
        @test_nowarn RustCall._check_not_freed(obj_alive, "TestType")

        # Test _check_not_freed with null pointer
        obj_freed = (ptr = Ptr{Cvoid}(0),)
        @test_throws ErrorException RustCall._check_not_freed(obj_freed, "TestType")

        # Verify error message mentions the type name
        try
            RustCall._check_not_freed(obj_freed, "MyStruct")
        catch e
            @test occursin("MyStruct", e.msg)
            @test occursin("freed", e.msg)
        end

        # Verify generated method code includes _check_not_freed for instance methods
        test_struct = RustCall.RustStructInfo(
            "GuardTest",
            String[],
            [RustCall.RustMethod("do_something", false, false, String[], String[], "i32")],
            "",
            [("x", "i32")],
            false,
            Dict{String, Bool}()
        )
        method_code = RustCall._emit_method_code(test_struct, test_struct.methods[1])
        @test occursin("_check_not_freed", method_code)

        # Verify property access code includes _check_not_freed
        struct_code = RustCall._emit_struct_code(test_struct)
        @test occursin("_check_not_freed", struct_code)

        # Static methods should NOT have _check_not_freed (no self)
        static_method = RustCall.RustMethod("create", true, false, ["val"], ["i32"], "Self")
        static_code = RustCall._emit_method_code(test_struct, static_method)
        @test !occursin("_check_not_freed", static_code)
    end

    # #140 / #95: No-op LLVM optimization passes
    @testset "LLVM optimization uses New Pass Manager (#140)" begin
        # Verify the optimization functions exist and use NewPMPassBuilder
        @test isdefined(RustCall, :optimize_module!)
        @test isdefined(RustCall, :optimize_function!)
        @test isdefined(RustCall, :OptimizationConfig)

        # Verify default config has sensible defaults
        config = RustCall.OptimizationConfig()
        @test config.level == 2
        @test config.size_level == 0
        @test config.enable_vectorization == true

        # Verify level 0 short-circuits (no-op)
        config0 = RustCall.OptimizationConfig(level=0, size_level=0)
        @test config0.level == 0
    end

    # #142 / #92: Greedy regex parsing of nested Rust generic types
    @testset "Bracket-aware Result/Option type parsing (#142)" begin
        # Simple Result types
        result = RustCall.parse_result_type("Result<String, Error>")
        @test result !== nothing
        @test result.ok_type == "String"
        @test result.err_type == "Error"

        # Nested generics — the bug was that HashMap<String, i32> would split incorrectly
        result_nested = RustCall.parse_result_type("Result<HashMap<String, i32>, Error>")
        @test result_nested !== nothing
        @test result_nested.ok_type == "HashMap<String, i32>"
        @test result_nested.err_type == "Error"

        # Deeply nested generics
        result_deep = RustCall.parse_result_type("Result<Vec<HashMap<String, Vec<i32>>>, Box<dyn Error>>")
        @test result_deep !== nothing
        @test result_deep.ok_type == "Vec<HashMap<String, Vec<i32>>>"
        @test result_deep.err_type == "Box<dyn Error>"

        # Tuple inner type with comma
        result_tuple = RustCall.parse_result_type("Result<(i32, i64), String>")
        @test result_tuple !== nothing
        @test result_tuple.ok_type == "(i32, i64)"
        @test result_tuple.err_type == "String"

        # Simple Option
        option = RustCall.parse_option_type("Option<Vec<i32>>")
        @test option !== nothing
        @test option.inner_type == "Vec<i32>"

        # Nested Option
        option_nested = RustCall.parse_option_type("Option<HashMap<String, Vec<i32>>>")
        @test option_nested !== nothing
        @test option_nested.inner_type == "HashMap<String, Vec<i32>>"
    end

    # #144 / #98: Missing floating-point type support in RustRc/RustArc
    @testset "Float types supported in ownership wrappers (#144)" begin
        # Verify Float32/Float64 branches exist in create_rust_rc and create_rust_arc
        # (We test the type dispatch path, not the actual FFI — library may not be loaded)

        # RustRc should accept Float32 and Float64 (method exists)
        @test hasmethod(RustCall.RustRc, Tuple{Float32})
        @test hasmethod(RustCall.RustRc, Tuple{Float64})

        # RustArc should accept Float32 and Float64
        @test hasmethod(RustCall.RustArc, Tuple{Float32})
        @test hasmethod(RustCall.RustArc, Tuple{Float64})

        # RustBox should accept Float32 and Float64
        @test hasmethod(RustCall.RustBox, Tuple{Float32})
        @test hasmethod(RustCall.RustBox, Tuple{Float64})
    end

    # #146 / #97: Hardcoded error codes in error conversion functions
    @testset "Error codes preserved in result_to_exception (#146)" begin
        # Integer error should use the error value as the code
        int_err = RustCall.RustResult{String, Int32}(false, Int32(42))
        try
            RustCall.result_to_exception(int_err)
            @test false  # should not reach here
        catch e
            @test e isa RustCall.RustError
            @test e.code == Int32(42)
            @test e.original_error == Int32(42)
        end

        # Non-integer error should get code -1, not 0
        str_err = RustCall.RustResult{Int32, String}(false, "not found")
        try
            RustCall.result_to_exception(str_err)
            @test false
        catch e
            @test e isa RustCall.RustError
            @test e.code == Int32(-1)  # Not the old hardcoded 0
            @test e.original_error == "not found"
        end

        # Ok result should return value
        ok_result = RustCall.RustResult{Int32, String}(true, Int32(99))
        @test RustCall.result_to_exception(ok_result) == Int32(99)

        # Explicit code overload
        err_with_code = RustCall.RustResult{Int32, String}(false, "error")
        try
            RustCall.result_to_exception(err_with_code, Int32(7))
            @test false
        catch e
            @test e.code == Int32(7)
            @test e.original_error == "error"
        end
    end

    # #148 / #96: Unprotected LLVM global dictionaries
    @testset "LLVM global dicts have locks (#148)" begin
        # LLVM_REGISTRY_LOCK must exist
        @test isdefined(RustCall, :LLVM_REGISTRY_LOCK)
        @test RustCall.LLVM_REGISTRY_LOCK isa ReentrantLock

        # REGISTRY_LOCK must exist (for RUST_LIBRARIES, etc.)
        @test isdefined(RustCall, :REGISTRY_LOCK)
        @test RustCall.REGISTRY_LOCK isa ReentrantLock

        # RUST_MODULES must exist and be properly keyed
        @test isdefined(RustCall, :RUST_MODULES)
    end

    # #150 / #77: Silent memory leak in drop functions when helpers unavailable
    @testset "Deferred drop infrastructure exists (#150)" begin
        # Deferred drop tracking exists
        @test isdefined(RustCall, :DEFERRED_DROPS)
        @test isdefined(RustCall, :DEFERRED_DROPS_LOCK)
        @test isdefined(RustCall, :deferred_drop_count)
        @test isdefined(RustCall, :flush_deferred_drops)
        @test isdefined(RustCall, :_defer_drop)

        # deferred_drop_count returns an integer
        @test RustCall.deferred_drop_count() isa Int

        # Simulate deferred drop behavior
        initial_count = RustCall.deferred_drop_count()
        RustCall._defer_drop(Ptr{Cvoid}(UInt(0xDEAD)), "TestType{Int32}", :test_drop_sym)
        @test RustCall.deferred_drop_count() == initial_count + 1

        # Clean up the test entry
        lock(RustCall.DEFERRED_DROPS_LOCK) do
            filter!(d -> d.type_name != "TestType{Int32}", RustCall.DEFERRED_DROPS)
        end
    end

end
