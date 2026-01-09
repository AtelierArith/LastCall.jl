using LastCall
using LastCall: parse_structs_and_impls, generate_struct_wrappers

function debug_hash()
    code = """
//! ```cargo
//! [dependencies]
//! rand = "0.8"
//! ```

use rand::Rng;

pub struct MonteCarloPi {
    total_samples: u64,
    inside_circle: u64,
}

impl MonteCarloPi {
    pub fn new() -> Self {
        Self {
            total_samples: 0,
            inside_circle: 0,
        }
    }
}
"""

    println("Original Code Hash: ", string(hash(code), base=16))

    structs = parse_structs_and_impls(code)
    augmented_code = code
    for info in structs
        augmented_code *= generate_struct_wrappers(info)
    end

    println("Augmented Code Hash: ", string(hash(augmented_code), base=16))

    if augmented_code == code
        println("WARNING: Code not changed!")
    else
        println("Code changed successfully.")
        # println(augmented_code)
    end
end

debug_hash()
