Read also AGENTS.md

# CLAUDE.md - RustCall.jl Development Guide

This document summarizes the **current** architecture and developer workflow for RustCall.jl.

## Project Purpose

RustCall.jl provides Julia ↔ Rust interoperability with:
- `rust"""..."""` / `@rust_str` for compiling Rust snippets
- `@rust` for FFI calls
- `@irust` for inline/function-scope Rust execution
- `#[julia]` support and auto-generated Julia wrappers
- `@rust_crate` for binding external Rust crates
- experimental `@rust_llvm` path for LLVM-level integration

## Current Status

Implemented and actively tested:
- Core FFI workflow (`rust"""` + `@rust`)
- Type translation and string conversion
- `RustResult` / `RustOption` wrappers and exception conversion
- Cargo dependency parsing and external crate integration
- Struct/object mapping and generated wrappers
- `#[julia]` transformation and wrapper emission
- Crate scanning/binding generation (`@rust_crate`)
- Ownership/runtime types (`RustBox`, `RustRc`, `RustArc`, `RustVec`, `RustSlice`)
- Hot reload support for crate workflows
- Cache system for compiled artifacts

## Key Source Layout

### Core module
- `src/RustCall.jl`: module entrypoint, exports, initialization, include order.

### Compilation and FFI pipeline
- `src/compiler.jl`: rustc integration and compilation orchestration.
- `src/ruststr.jl`: `rust"""` handling, code registration/loading.
- `src/rustmacro.jl`: `@rust`, `@irust` macro expansion and call path.
- `src/codegen.jl`: `ccall` expression generation helpers.
- `src/llvmintegration.jl`, `src/llvmcodegen.jl`, `src/llvmoptimization.jl`: LLVM integration and optimization.

### Type system and runtime wrappers
- `src/types.jl`: Rust/Julia wrapper types and ownership abstractions.
- `src/typetranslation.jl`: Rust type string ↔ Julia type mapping.
- `src/exceptions.jl`: rich error types and formatting.
- `src/memory.jl`: helper-backed ownership operations.

### Cargo and crate bindings
- `src/dependencies.jl`, `src/dependency_resolution.jl`: cargo dependency parsing/resolution.
- `src/cargoproject.jl`, `src/cargobuild.jl`: Cargo project generation and build flow.
- `src/julia_functions.jl`: `#[julia]` parsing/transform/wrapper support.
- `src/crate_bindings.jl`: crate scan, wrapper generation, `@rust_crate`.
- `src/hot_reload.jl`: file watching and reload orchestration.

### Caching and generics
- `src/cache.jl`: compiled artifact cache management.
- `src/generics.jl`: generic function monomorphization and registry helpers.

## Test Layout

- Root test entry: `test/runtests.jl`
- Feature tests include:
  - ownership/types/arrays/generics
  - cargo/dependency/external crate workflows
  - `#[julia]` and crate binding generation
  - hot reload and regressions
- Rust proc-macro tests: `deps/juliacall_macros/tests/`

## Required Tooling

- Julia `1.12+` (per `Project.toml` compat)
- Rust toolchain (`rustc`, `cargo`)

Build helper library when needed:
```julia
using Pkg
Pkg.build("RustCall")
```

## Common Development Commands

### Julia package
```bash
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project -e 'using Pkg; Pkg.build("RustCall")'
julia --project -e 'using Pkg; Pkg.test()'
```

### Docs and benchmarks
```bash
julia --project=docs docs/make.jl
julia --project benchmark/benchmarks.jl
```

### Proc-macro crate
```bash
cd deps/juliacall_macros
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-features
```

## Design References

- `docs/design/Phase1.md`
- `docs/design/Phase2.md`
- `docs/design/Phase3.md`
- `docs/design/Phase4.md`
- `docs/design/INTERNAL.md`
- `docs/design/LLVMCALL.md`
- `docs/design/DESCRIPTION.md`

## Contributor Guidance

- Keep new functionality accompanied by tests under `test/`.
- Prefer extending existing architecture modules over introducing parallel pipelines.
- Keep generated/binding code paths deterministic and cache-aware.
- Treat `Cxx.jl/` and `julia/` as vendored unless a task explicitly targets them.
