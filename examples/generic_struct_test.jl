using LastCall
using Test

println("--- Generic Struct Test ---")

rust"""
pub struct Wrapper<T> {
    value: T,
}

impl<T> Wrapper<T> {
    pub fn new(value: T) -> Self {
        Self { value }
    }

    pub fn get_value(&self) -> T where T: Copy {
        self.value
    }

    pub fn set_value(&mut self, val: T) {
        self.value = val;
    }
}
"""

@testset "Generic Wrapper" begin
    println("Creating Wrapper{Int32}...")
    w = Wrapper{Int32}(Int32(42))
    println("Wrapper created: ", w)

    val = get_value(w)
    println("Value: ", val)
    @test val == 42

    set_value(w, Int32(100))
    val2 = get_value(w)
    println("Value 2: ", val2)
    @test val2 == 100
end
