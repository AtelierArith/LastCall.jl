# Memory management for Rust ownership types
# Phase 2: Automatic integration with Rust memory management

using Libdl

# Registry for Rust helper library
const RUST_HELPERS_LIB = Ref{Union{Ptr{Cvoid}, Nothing}}(nothing)

"""
    get_rust_helpers_lib() -> Union{Ptr{Cvoid}, Nothing}

Get or load the Rust helpers library.
This library provides FFI functions for Box, Rc, Arc operations.
Returns nothing if the library is not available.
"""
function get_rust_helpers_lib()
    return RUST_HELPERS_LIB[]
end

"""
    is_rust_helpers_available() -> Bool

Check if the Rust helpers library is available.
"""
function is_rust_helpers_available()
    return RUST_HELPERS_LIB[] !== nothing
end

"""
    load_rust_helpers_lib(lib_path::String)

Load the Rust helpers library from a file path.
"""
function load_rust_helpers_lib(lib_path::String)
    lib_handle = Libdl.dlopen(lib_path, Libdl.RTLD_GLOBAL | Libdl.RTLD_NOW)
    if lib_handle == C_NULL
        error("Failed to load Rust helpers library: $lib_path")
    end
    RUST_HELPERS_LIB[] = lib_handle
    return lib_handle
end

# ============================================================================
# Box<T> creation and management
# ============================================================================

"""
    create_rust_box(value::T) -> RustBox{T} where T

Create a RustBox from a Julia value.
Automatically calls the appropriate Rust Box::new function.
"""
function create_rust_box(value::T) where T
    if !is_rust_helpers_available()
        error("Rust helpers library not loaded. Cannot create RustBox. Please compile deps/rust_helpers.")
    end
    
    lib = get_rust_helpers_lib()
    
    # Dispatch based on type - use dlsym to get function pointer
    if T == Int32
        fn_ptr = Libdl.dlsym(lib, :rust_box_new_i32)
        ptr = ccall(fn_ptr, Ptr{Cvoid}, (Int32,), value)
        return RustBox{Int32}(ptr)
    elseif T == Int64
        fn_ptr = Libdl.dlsym(lib, :rust_box_new_i64)
        ptr = ccall(fn_ptr, Ptr{Cvoid}, (Int64,), value)
        return RustBox{Int64}(ptr)
    elseif T == Float32
        fn_ptr = Libdl.dlsym(lib, :rust_box_new_f32)
        ptr = ccall(fn_ptr, Ptr{Cvoid}, (Float32,), value)
        return RustBox{Float32}(ptr)
    elseif T == Float64
        fn_ptr = Libdl.dlsym(lib, :rust_box_new_f64)
        ptr = ccall(fn_ptr, Ptr{Cvoid}, (Float64,), value)
        return RustBox{Float64}(ptr)
    elseif T == Bool
        fn_ptr = Libdl.dlsym(lib, :rust_box_new_bool)
        ptr = ccall(fn_ptr, Ptr{Cvoid}, (Bool,), value)
        return RustBox{Bool}(ptr)
    else
        error("Unsupported type for RustBox: $T")
    end
end

"""
    drop_rust_box(box::RustBox{T}) where T

Drop a RustBox, calling the appropriate Rust drop function.
"""
function drop_rust_box(box::RustBox{T}) where T
    if box.dropped || box.ptr == C_NULL
        return nothing
    end
    
    lib = get_rust_helpers_lib()
    if lib === nothing
        @warn "Rust helpers library not loaded. Cannot properly drop RustBox."
        box.dropped = true
        return nothing
    end
    
    # Dispatch based on type
    if T == Int32
        fn_ptr = Libdl.dlsym(lib, :rust_box_drop_i32)
        ccall(fn_ptr, Cvoid, (Ptr{Cvoid},), box.ptr)
    elseif T == Int64
        fn_ptr = Libdl.dlsym(lib, :rust_box_drop_i64)
        ccall(fn_ptr, Cvoid, (Ptr{Cvoid},), box.ptr)
    elseif T == Float32
        fn_ptr = Libdl.dlsym(lib, :rust_box_drop_f32)
        ccall(fn_ptr, Cvoid, (Ptr{Cvoid},), box.ptr)
    elseif T == Float64
        fn_ptr = Libdl.dlsym(lib, :rust_box_drop_f64)
        ccall(fn_ptr, Cvoid, (Ptr{Cvoid},), box.ptr)
    elseif T == Bool
        fn_ptr = Libdl.dlsym(lib, :rust_box_drop_bool)
        ccall(fn_ptr, Cvoid, (Ptr{Cvoid},), box.ptr)
    else
        # Fallback to generic drop (unsafe)
        fn_ptr = Libdl.dlsym(lib, :rust_box_drop)
        ccall(fn_ptr, Cvoid, (Ptr{Cvoid},), box.ptr)
    end
    
    box.dropped = true
    box.ptr = C_NULL
    return nothing
end

# Override drop! for RustBox to call Rust drop
function drop!(box::RustBox{T}) where T
    drop_rust_box(box)
end

# ============================================================================
# Rc<T> creation and management
# ============================================================================

"""
    create_rust_rc(value::T) -> RustRc{T} where T

Create a RustRc from a Julia value.
Automatically calls the appropriate Rust Rc::new function.
"""
function create_rust_rc(value::T) where T
    if !is_rust_helpers_available()
        error("Rust helpers library not loaded. Cannot create RustRc. Please compile deps/rust_helpers.")
    end
    
    lib = get_rust_helpers_lib()
    
    if T == Int32
        fn_ptr = Libdl.dlsym(lib, :rust_rc_new_i32)
        ptr = ccall(fn_ptr, Ptr{Cvoid}, (Int32,), value)
        return RustRc{Int32}(ptr)
    elseif T == Int64
        fn_ptr = Libdl.dlsym(lib, :rust_rc_new_i64)
        ptr = ccall(fn_ptr, Ptr{Cvoid}, (Int64,), value)
        return RustRc{Int64}(ptr)
    else
        error("Unsupported type for RustRc: $T")
    end
end

"""
    clone(rc::RustRc{T}) -> RustRc{T} where T

Clone a RustRc, incrementing the reference count.
"""
function clone(rc::RustRc{T}) where T
    if rc.dropped || rc.ptr == C_NULL
        error("Cannot clone a dropped RustRc")
    end
    
    if !is_rust_helpers_available()
        error("Rust helpers library not loaded. Cannot clone RustRc.")
    end
    
    lib = get_rust_helpers_lib()
    
    # For now, we'll use a simple approach
    # In production, type-specific clone functions should be used
    fn_ptr = Libdl.dlsym(lib, :rust_rc_clone)
    new_ptr = ccall(fn_ptr, Ptr{Cvoid}, (Ptr{Cvoid},), rc.ptr)
    return RustRc{T}(new_ptr)
end

"""
    drop_rust_rc(rc::RustRc{T}) where T

Drop a RustRc, decrementing the reference count.
"""
function drop_rust_rc(rc::RustRc{T}) where T
    if rc.dropped || rc.ptr == C_NULL
        return nothing
    end
    
    lib = get_rust_helpers_lib()
    if lib === nothing
        @warn "Rust helpers library not loaded. Cannot properly drop RustRc."
        rc.dropped = true
        return nothing
    end
    
    if T == Int32
        fn_ptr = Libdl.dlsym(lib, :rust_rc_drop_i32)
        ccall(fn_ptr, Cvoid, (Ptr{Cvoid},), rc.ptr)
    elseif T == Int64
        fn_ptr = Libdl.dlsym(lib, :rust_rc_drop_i64)
        ccall(fn_ptr, Cvoid, (Ptr{Cvoid},), rc.ptr)
    else
        error("Unsupported type for RustRc drop: $T")
    end
    
    rc.dropped = true
    rc.ptr = C_NULL
    return nothing
end

# Override drop! for RustRc
function drop!(rc::RustRc{T}) where T
    drop_rust_rc(rc)
end

# ============================================================================
# Arc<T> creation and management
# ============================================================================

"""
    create_rust_arc(value::T) -> RustArc{T} where T

Create a RustArc from a Julia value.
Automatically calls the appropriate Rust Arc::new function.
"""
function create_rust_arc(value::T) where T
    if !is_rust_helpers_available()
        error("Rust helpers library not loaded. Cannot create RustArc. Please compile deps/rust_helpers.")
    end
    
    lib = get_rust_helpers_lib()
    
    if T == Int32
        fn_ptr = Libdl.dlsym(lib, :rust_arc_new_i32)
        ptr = ccall(fn_ptr, Ptr{Cvoid}, (Int32,), value)
        return RustArc{Int32}(ptr)
    elseif T == Int64
        fn_ptr = Libdl.dlsym(lib, :rust_arc_new_i64)
        ptr = ccall(fn_ptr, Ptr{Cvoid}, (Int64,), value)
        return RustArc{Int64}(ptr)
    elseif T == Float64
        fn_ptr = Libdl.dlsym(lib, :rust_arc_new_f64)
        ptr = ccall(fn_ptr, Ptr{Cvoid}, (Float64,), value)
        return RustArc{Float64}(ptr)
    else
        error("Unsupported type for RustArc: $T")
    end
end

"""
    clone(arc::RustArc{T}) -> RustArc{T} where T

Clone a RustArc, incrementing the atomic reference count.
"""
function clone(arc::RustArc{T}) where T
    if arc.dropped || arc.ptr == C_NULL
        error("Cannot clone a dropped RustArc")
    end
    
    if !is_rust_helpers_available()
        error("Rust helpers library not loaded. Cannot clone RustArc.")
    end
    
    lib = get_rust_helpers_lib()
    
    # Clone the Arc (increments reference count)
    fn_ptr = Libdl.dlsym(lib, :rust_arc_clone)
    new_ptr = ccall(fn_ptr, Ptr{Cvoid}, (Ptr{Cvoid},), arc.ptr)
    return RustArc{T}(new_ptr)
end

"""
    drop_rust_arc(arc::RustArc{T}) where T

Drop a RustArc, decrementing the atomic reference count.
"""
function drop_rust_arc(arc::RustArc{T}) where T
    if arc.dropped || arc.ptr == C_NULL
        return nothing
    end
    
    lib = get_rust_helpers_lib()
    if lib === nothing
        @warn "Rust helpers library not loaded. Cannot properly drop RustArc."
        arc.dropped = true
        return nothing
    end
    
    if T == Int32
        fn_ptr = Libdl.dlsym(lib, :rust_arc_drop_i32)
        ccall(fn_ptr, Cvoid, (Ptr{Cvoid},), arc.ptr)
    elseif T == Int64
        fn_ptr = Libdl.dlsym(lib, :rust_arc_drop_i64)
        ccall(fn_ptr, Cvoid, (Ptr{Cvoid},), arc.ptr)
    elseif T == Float64
        fn_ptr = Libdl.dlsym(lib, :rust_arc_drop_f64)
        ccall(fn_ptr, Cvoid, (Ptr{Cvoid},), arc.ptr)
    else
        error("Unsupported type for RustArc drop: $T")
    end
    
    arc.dropped = true
    arc.ptr = C_NULL
    return nothing
end

# Override drop! for RustArc
function drop!(arc::RustArc{T}) where T
    drop_rust_arc(arc)
end

# ============================================================================
# Convenience constructors
# ============================================================================

# RustBox constructors
RustBox(value::Int32) = create_rust_box(value)
RustBox(value::Int64) = create_rust_box(value)
RustBox(value::Float32) = create_rust_box(value)
RustBox(value::Float64) = create_rust_box(value)
RustBox(value::Bool) = create_rust_box(value)

# RustRc constructors
RustRc(value::Int32) = create_rust_rc(value)
RustRc(value::Int64) = create_rust_rc(value)

# RustArc constructors
RustArc(value::Int32) = create_rust_arc(value)
RustArc(value::Int64) = create_rust_arc(value)
RustArc(value::Float64) = create_rust_arc(value)

# ============================================================================
# Update finalizers to call Rust drop functions
# ============================================================================

# Update RustBox finalizer
function update_box_finalizer(box::RustBox{T}) where T
    finalizer(box) do b
        if !b.dropped && b.ptr != C_NULL
            try
                drop_rust_box(b)
            catch e
                @warn "Error dropping RustBox in finalizer: $e"
            end
        end
    end
end

# Update RustRc finalizer
function update_rc_finalizer(rc::RustRc{T}) where T
    finalizer(rc) do r
        if !r.dropped && r.ptr != C_NULL
            try
                drop_rust_rc(r)
            catch e
                @warn "Error dropping RustRc in finalizer: $e"
            end
        end
    end
end

# Update RustArc finalizer
function update_arc_finalizer(arc::RustArc{T}) where T
    finalizer(arc) do a
        if !a.dropped && a.ptr != C_NULL
            try
                drop_rust_arc(a)
            catch e
                @warn "Error dropping RustArc in finalizer: $e"
            end
        end
    end
end
