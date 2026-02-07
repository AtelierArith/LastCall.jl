# API Reference

This page provides the API documentation for RustCall.jl.

## Macros

```@docs
@rust
@rust_str
@irust
@irust_str
@rust_llvm
```

## Types

### Result and Option Types

```@docs
RustResult
RustOption
```

### Ownership Types

```@docs
RustBox
RustRc
RustArc
RustVec
RustSlice
```

### Pointer Types

```@docs
RustPtr
RustRef
```

### String Types

```@docs
RustString
RustStr
```

### Error Types

```@docs
RustError
CompilationError
RuntimeError
CargoBuildError
DependencyResolutionError
```

## Type Conversion Functions

```@docs
rusttype_to_julia
juliatype_to_rust
```

## Result/Option Operations

```@docs
unwrap
unwrap_or
is_ok
is_err
is_some
is_none
result_to_exception
unwrap_or_throw
```

## String Conversion Functions

```@docs
rust_string_to_julia
rust_str_to_julia
julia_string_to_rust
julia_string_to_cstring
cstring_to_julia_string
```

## Error Handling

```@docs
format_rustc_error
suggest_fix_for_error
```

## Compiler Functions

```@docs
RustCompiler
compile_with_recovery
check_rustc_available
get_rustc_version
get_default_compiler
set_default_compiler
compile_rust_to_shared_lib
compile_rust_to_llvm_ir
load_llvm_ir
wrap_rust_code
```

## Ownership Type Operations

```@docs
drop!
is_dropped
is_valid
clone
is_rust_helpers_available
get_rust_helpers_lib
get_rust_helpers_lib_path
```

## RustVec Operations

```@docs
create_rust_vec
rust_vec_get
rust_vec_set!
copy_to_julia!
to_julia_vector
```

## Cache Management

```@docs
clear_cache
get_cache_size
list_cached_libraries
cleanup_old_cache
```

## LLVM Optimization

```@docs
OptimizationConfig
optimize_module!
optimize_for_speed!
optimize_for_size!
```

## LLVM Function Registration

```@docs
RustFunctionInfo
compile_and_register_rust_function
julia_type_to_llvm_ir_string
```

## Generics Support

```@docs
register_generic_function
call_generic_function
is_generic_function
monomorphize_function
specialize_generic_code
infer_type_parameters
```

## Generic Constraints

```@docs
TraitBound
TypeConstraints
GenericFunctionInfo
parse_trait_bounds
parse_single_trait
parse_where_clause
parse_inline_constraints
parse_generic_function
constraints_to_rust_string
merge_constraints
```

## External Library Integration

### Dependency Management

```@docs
DependencySpec
parse_dependencies_from_code
has_dependencies
```

### Cargo Project Management

```@docs
CargoProject
create_cargo_project
build_cargo_project
clear_cargo_cache
get_cargo_cache_size
```

## Crate Bindings

```@docs
CrateInfo
CrateBindingOptions
scan_crate
generate_bindings
write_bindings_to_file
@rust_crate
```

## Hot Reload

```@docs
HotReloadState
enable_hot_reload
disable_hot_reload
disable_all_hot_reload
is_hot_reload_enabled
list_hot_reload_crates
trigger_reload
set_hot_reload_global
enable_hot_reload_for_crate
```

## Type System

### Type Mapping Constants

The following constants define the mapping between Rust types and Julia types:

```julia
# Rust to Julia type mapping
const RUST_TO_JULIA_TYPE_MAP = Dict{Symbol, Type}(
    :i8 => Int8,
    :i16 => Int16,
    :i32 => Int32,
    :i64 => Int64,
    :u8 => UInt8,
    :u16 => UInt16,
    :u32 => UInt32,
    :u64 => UInt64,
    :f32 => Float32,
    :f64 => Float64,
    :bool => Bool,
    :usize => UInt,
    :isize => Int,
    Symbol("()") => Cvoid,
)

# Julia to Rust type mapping
const JULIA_TO_RUST_TYPE_MAP = Dict{Type, String}(
    Int8 => "i8",
    Int16 => "i16",
    Int32 => "i32",
    Int64 => "i64",
    UInt8 => "u8",
    UInt16 => "u16",
    UInt32 => "u32",
    UInt64 => "u64",
    Float32 => "f32",
    Float64 => "f64",
    Bool => "bool",
    Cvoid => "()",
)
```

### Internal Registries

The following registries are used internally by RustCall.jl:

```@docs
GENERIC_FUNCTION_REGISTRY
MONOMORPHIZED_FUNCTIONS
```

The following registries and constants are not exported but are available for advanced usage.

Note: These constants are internal implementation details. They are documented here for completeness but should not be accessed directly by users.

```@autodocs
Modules = [RustCall]
Private = true
Filter = t -> begin
    name = try
        nameof(t)
    catch
        return false
    end
    target_names = [
        :RUST_LIBRARIES, :RUST_MODULE_REGISTRY, :FUNCTION_REGISTRY, :IRUST_FUNCTIONS,
        :CURRENT_LIB, :RUST_TO_JULIA_TYPE_MAP, :JULIA_TO_RUST_TYPE_MAP
    ]
    return name in target_names
end
```

## Utility Functions

### Testing and Debugging

These functions are exported for testing purposes but are considered internal.
They are wrappers around internal implementation functions.

## Internal Functions and Types

The following functions and types are internal implementation details and are not part of the public API.
They are documented here for completeness but should not be used directly by users.

```@autodocs
Modules = [RustCall]
Filter = t -> begin
    # Exclude items already documented in @docs blocks above
    excluded_names = [
        # Types (documented in @docs blocks)
        :RustResult, :RustOption, :RustBox, :RustRc, :RustArc, :RustVec, :RustSlice,
        :RustPtr, :RustRef, :RustString, :RustStr,
        :RustError, :CompilationError, :RuntimeError, :CargoBuildError, :DependencyResolutionError,
        :RustCompiler, :OptimizationConfig, :RustFunctionInfo,
        :DependencySpec, :CargoProject,
        # Constants/Registries (documented in @docs blocks)
        :GENERIC_FUNCTION_REGISTRY, :MONOMORPHIZED_FUNCTIONS,
        :RUST_LIBRARIES, :RUST_MODULE_REGISTRY, :FUNCTION_REGISTRY, :IRUST_FUNCTIONS,
        # Public functions already documented
        :unwrap, :unwrap_or, :is_ok, :is_err, :is_some, :is_none,
        :result_to_exception, :unwrap_or_throw,
        :rusttype_to_julia, :juliatype_to_rust,
        :rust_string_to_julia, :rust_str_to_julia,
        :julia_string_to_rust, :julia_string_to_cstring, :cstring_to_julia_string,
        :format_rustc_error, :suggest_fix_for_error,
        :compile_with_recovery, :check_rustc_available, :get_rustc_version,
        :get_default_compiler, :set_default_compiler, :compile_rust_to_shared_lib,
        :compile_rust_to_llvm_ir, :load_llvm_ir, :wrap_rust_code,
        :drop!, :is_dropped, :is_valid, :clone, :is_rust_helpers_available,
        :get_rust_helpers_lib, :get_rust_helpers_lib_path,
        :create_rust_vec, :rust_vec_get, :rust_vec_set!, :copy_to_julia!, :to_julia_vector,
        :clear_cache, :get_cache_size, :list_cached_libraries, :cleanup_old_cache,
        :optimize_module!, :optimize_for_speed!, :optimize_for_size!,
        :compile_and_register_rust_function,
        :register_generic_function, :call_generic_function, :is_generic_function,
        :monomorphize_function, :specialize_generic_code, :infer_type_parameters,
        :parse_dependencies_from_code, :has_dependencies,
        :create_cargo_project, :build_cargo_project,
        :clear_cargo_cache, :get_cargo_cache_size,
        :julia_type_to_llvm_ir_string,
        :TraitBound, :TypeConstraints, :GenericFunctionInfo,
        :parse_trait_bounds, :parse_single_trait, :parse_where_clause,
        :parse_inline_constraints, :parse_generic_function,
        :constraints_to_rust_string, :merge_constraints,
        :CrateInfo, :CrateBindingOptions,
        :scan_crate, :generate_bindings, :write_bindings_to_file,
        :HotReloadState,
        :enable_hot_reload, :disable_hot_reload, :disable_all_hot_reload,
        :is_hot_reload_enabled, :list_hot_reload_crates,
        :trigger_reload, :set_hot_reload_global, :enable_hot_reload_for_crate,
        # Macros (documented separately)
        Symbol("@rust"), Symbol("@rust_str"), Symbol("@irust"), Symbol("@irust_str"),
        Symbol("@rust_llvm"), Symbol("@rust_crate"),
    ]
    # Get the binding name
    name = try
        nameof(t)
    catch
        return false
    end
    # Include all documented items that are not in the excluded list
    # This includes internal functions, types, and Base method extensions
    return !(name in excluded_names)
end
```
