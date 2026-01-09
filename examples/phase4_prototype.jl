# Phase 4 Prototype: Manual Struct Mapping
# This example demonstrates the pattern that Phase 4 will automate.

using LastCall
using Test

# 1. Define Rust struct and implementation
# In Phase 4, the FFI wrappers below will be generated automatically.
rust"""
pub struct Rectangle {
    width: f64,
    height: f64,
}

impl Rectangle {
    pub fn new(width: f64, height: f64) -> Self {
        println!("Rust: Creating Rectangle({}x{})", width, height);
        Self { width, height }
    }

    pub fn area(&self) -> f64 {
        self.width * self.height
    }

    pub fn scale(&mut self, factor: f64) {
        self.width *= factor;
        self.height *= factor;
    }
}

// --- FFI Wrappers (Will be auto-generated in Phase 4) ---

#[no_mangle]
pub extern "C" fn Rectangle_new(width: f64, height: f64) -> *mut Rectangle {
    let rect = Rectangle::new(width, height);
    Box::into_raw(Box::new(rect))
}

#[no_mangle]
pub extern "C" fn Rectangle_area(ptr: *const Rectangle) -> f64 {
    let rect = unsafe { &*ptr };
    rect.area()
}

#[no_mangle]
pub extern "C" fn Rectangle_scale(ptr: *mut Rectangle, factor: f64) {
    let rect = unsafe { &mut *ptr };
    rect.scale(factor);
}

#[no_mangle]
pub extern "C" fn Rectangle_free(ptr: *mut Rectangle) {
    if !ptr.is_null() {
        println!("Rust: Dropping Rectangle");
        unsafe { Box::from_raw(ptr); }
    }
}
"""

# 2. Julia Wrapper (Will be auto-generated in Phase 4)
mutable struct Rectangle
    ptr::Ptr{Cvoid}

    function Rectangle(width::Float64, height::Float64)
        # Create on Rust heap
        ptr = @rust Rectangle_new(width, height)::Ptr{Cvoid}

        # Wrap in Julia object
        obj = new(ptr)

        # Attach finalizer for automatic memory management
        finalizer(obj) do r
            if r.ptr != C_NULL
                @rust Rectangle_free(r.ptr)
                # Avoid double free
                r.ptr = C_NULL
            end
        end
        return obj
    end
end

# Define methods on the Julia type
area(r::Rectangle) = @rust Rectangle_area(r.ptr)::Float64
scale!(r::Rectangle, factor::Float64) = @rust Rectangle_scale(r.ptr, factor)

# --- Usage Example ---

println("--- Stage 1: Creation ---")
rect = Rectangle(10.0, 20.0)

println("\n--- Stage 2: Method Calls ---")
println("Initial area: ", area(rect))

scale!(rect, 2.0)
println("Area after 2x scale: ", area(rect))

println("\n--- Stage 3: Lifecycle ---")
println("Clearing reference to rect...")
rect = nothing # The object is now eligible for GC

# Force GC to demonstrate the finalizer (calling Rust's Drop)
GC.gc()
println("GC triggered.")
