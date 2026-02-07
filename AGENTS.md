Read also CLAUDE.md

# Repository Guidelines

## Project Structure & Module Organization
- `src/` is the main RustCall implementation. Entry point is `src/RustCall.jl`.
- `test/` contains the root package test suite (`test/runtests.jl` includes all feature test files).
- `docs/` is the Documenter project (`docs/make.jl`, `docs/src/`, `docs/design/`).
- `benchmark/` holds BenchmarkTools scripts for macro/LLVM/ownership performance checks.
- `deps/` contains build-time Rust assets:
  - `deps/build.jl` builds helper libraries during `Pkg.build("RustCall")`
  - `deps/rust_helpers/` provides ownership/runtime helper functions
  - `deps/juliacall_macros/` is the proc-macro crate for `#[julia]`
- `examples/` contains runnable integration examples (`MyExample.jl`, `sample_crate`, `sample_crate_pyo3`).
- `Cxx.jl/` and `julia/` are vendored upstream trees. Avoid edits unless explicitly required.

## Build, Test, and Development Commands
- Setup environment: `julia --project -e 'using Pkg; Pkg.instantiate()'`
- Build Rust helpers (recommended before full tests): `julia --project -e 'using Pkg; Pkg.build("RustCall")'`
- Run package tests: `julia --project -e 'using Pkg; Pkg.test()'`
- Run a specific test file directly: `julia --project test/test_hot_reload.jl`
- Run proc-macro crate checks:
  - `cd deps/juliacall_macros && cargo fmt --check`
  - `cd deps/juliacall_macros && cargo clippy --all-targets --all-features -- -D warnings`
  - `cd deps/juliacall_macros && cargo test --all-features`
- Build docs: `julia --project=docs docs/make.jl`
- Run benchmarks: `julia --project benchmark/benchmarks.jl`

## Coding Style & Naming Conventions
- Julia style: 4-space indentation, no tabs.
- Naming: modules/types in `CamelCase`; functions/variables in `snake_case`.
- Keep functionality split by concern (compiler/codegen/types/cache/crate bindings/hot reload).
- Prefer extending existing modules in `src/` over adding new top-level files unless separation is clear.
- Do not change vendored trees (`Cxx.jl/`, `julia/`) for RustCall features.

## Testing Guidelines
- Add or update tests in `test/` with focused `@testset`s near related functionality.
- If behavior touches macros or parsing (`rust"""`, `@rust`, `@irust`, `@rust_crate`), include regression coverage.
- For Rust helper / ownership behavior, ensure tests account for environments where helpers may be unavailable.
- For proc-macro changes, run `cargo test` in `deps/juliacall_macros` in addition to Julia tests.

## Commit & Pull Request Guidelines
- Use short imperative commit messages.
- In PRs, include:
  - Scope and affected areas (`src/`, `test/`, `docs/`, `deps/`)
  - Commands run (tests, cargo checks, docs/bench if relevant)
  - Any changes to vendored trees and the upstream reason/commit

## Agent Notes
- Rust toolchain (`rustc`, `cargo`) is required for most integration tests.
- CI runs Julia tests at repo root and Rust checks under `deps/juliacall_macros`.
- If work touches `julia/`, also follow `julia/AGENTS.md`.
