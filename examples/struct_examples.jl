using LastCall

println("--- LastCall.jl Struct Automation Example ---")

# Define a Rust struct and methods.
# LastCall automatically:
# 1. Detects `pub struct`
# 2. Generates `extern "C"` wrappers (new, free, methods)
# 3. Defines a Julia mutable struct `Person`
# 4. Defines Julia methods `greet`, `have_birthday`
rust"""
pub struct Person {
    age: u32,
    height: f64,
}

impl Person {
    pub fn new(age: u32, height: f64) -> Self {
        println!("Rust: Created Person(age={}, height={})", age, height);
        Self { age, height }
    }

    pub fn greet(&self) {
        println!("Rust: Hello, I am {} years old.", self.age);
    }

    pub fn have_birthday(&mut self) {
        self.age += 1;
        println!("Rust: Happy Birthday! Now I am {}.", self.age);
    }

    pub fn grow(&mut self, amount: f64) {
        self.height += amount;
    }

    pub fn get_details(&self) -> f64 {
        // Return height just to check return values
        self.height
    }
}
"""

# Usage in Julia
println("\nCreating person...")
p = Person(30, 175.5)

println("\nCalling methods...")
greet(p)

println("\nMutating state...")
have_birthday(p)
greet(p)

grow(p, 2.5)
println("New height: ", get_details(p))

println("\nCleaning up...")
p = nothing
GC.gc()
println("Done.")
