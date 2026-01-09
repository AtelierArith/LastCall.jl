# Phase 4 Example: Using ndarray inside a Struct
using LastCall

# Define a Rust struct that uses an external crate
rust"""
//! ```cargo
//! [dependencies]
//! ndarray = "0.15"
//! ```

use ndarray::Array2;

pub struct MatrixTool {
    data: Array2<f64>,
}

impl MatrixTool {
    pub fn new(rows: usize, cols: usize) -> Self {
        Self {
            data: Array2::zeros((rows, cols)),
        }
    }

    pub fn set(&mut self, row: usize, col: usize, val: f64) {
        if let Some(v) = self.data.get_mut((row, col)) {
            *v = val;
        }
    }

    pub fn sum(&self) -> f64 {
        self.data.sum()
    }
}
"""

# Usage in Julia
println("Creating MatrixTool(2, 2)...")
m = MatrixTool(2, 2)

println("Setting values...")
set(m, 0, 0, 1.5)
set(m, 1, 1, 2.5)

println("Calculating sum...")
total = sum(m)
println("Sum: ", total)

if total == 4.0
    println("Success!")
else
    println("Failed! Expected 4.0, got ", total)
end
