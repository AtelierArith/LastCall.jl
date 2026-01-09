# Phase 4 Example: Monte Carlo Pi Estimation
# This example uses an external crate (rand) and a Rust struct with internal state.

using LastCall
using Test
using Printf

println("Compiling Rust code with dependencies (rand)...")

rust"""
//! ```cargo
//! [dependencies]
//! rand = "0.8"
//! ```

use rand::Rng;

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

    /// Generates the specified number of samples and estimates Pi
    pub fn calculate(&mut self, samples: u64) -> f64 {
        for _ in 0..samples {
            let x: f64 = self.rng.gen_range(0.0..1.0);
            let y: f64 = self.rng.gen_range(0.0..1.0);

            let distance_squared = x * x + y * y;
            if distance_squared <= 1.0 {
                self.inside_circle += 1;
            }
            self.total_samples += 1;
        }

        self.estimate()
    }

    /// Estimates the value of Pi from the current samples
    pub fn estimate(&self) -> f64 {
        if self.total_samples == 0 {
            return 0.0;
        }
        4.0 * (self.inside_circle as f64) / (self.total_samples as f64)
    }

    /// Returns the total number of samples taken
    pub fn total_samples(&self) -> u64 {
        self.total_samples
    }

    /// Returns the number of points inside the circle
    pub fn inside_circle(&self) -> u64 {
        self.inside_circle
    }

    /// Resets all statistics
    pub fn reset(&mut self) {
        self.total_samples = 0;
        self.inside_circle = 0;
    }
}
"""

# Julia Side Usage
println("\n--- Monte Carlo Pi Simulation ---")

# 1. Create the object (calls MonteCarloPi::new() in Rust)
calc = MonteCarloPi()
println("Initial state: samples = ", total_samples(calc), ", estimate = ", estimate(calc))

# 2. Run simulation in batches
for i in 1:5
    samples = 200_000
    # Calls calculate(&mut self, samples: u64)
    current_estimate = calculate(calc, UInt64(samples))

    total = total_samples(calc)
    inside = inside_circle(calc)

    @printf("Batch %d: Total Samples = %10d, Pi Estimate = %.6f (Error: %.6f)\n",
            i, total, current_estimate, abs(current_estimate - pi))
end

# 3. Reset test
println("\nResetting calculator...")
reset(calc)
println("State after reset: samples = ", total_samples(calc), ", estimate = ", estimate(calc))

@test total_samples(calc) == 0
@test estimate(calc) == 0.0

println("\nSimulation complete. The Rust object will be dropped automatically by Julia's GC.")
