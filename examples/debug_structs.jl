# Debug structs and impls parsing
using LastCall
using LastCall: parse_structs_and_impls, generate_struct_wrappers

code = """
/// Struct for calculating the value of Pi using the Monte Carlo method
pub struct MonteCarloPi {
    total_samples: u64,
    inside_circle: u64,
    rng: rand::rngs::ThreadRng,
}

impl MonteCarloPi {
    /// Creates a new MonteCarloPi instance
    pub fn new() -> Self {
        Self {
            total_samples: 0,
            inside_circle: 0,
            rng: rand::thread_rng(),
        }
    }

    /// Estimates the value of Pi from the current samples
    pub fn estimate(&self) -> f64 {
        4.0
    }
}
"""

println("Parsing code...")
structs = parse_structs_and_impls(code)

if isempty(structs)
    println("No structs found!")
else
    for s in structs
        println("Found struct: ", s.name)
        for m in s.methods
            println("  Found method: ", m.name, " (static: ", m.is_static, ", mutable: ", m.is_mutable, ")")
        end

        println("\nGenerated Wrapper:")
        println(generate_struct_wrappers(s))
    end
end
