# Tests for array and collection types (RustVec, RustSlice)

using RustCall
using Test
using Libdl

# Helper function to check if Vec functions are available in the Rust helpers library
function is_vec_helpers_available()
    if !RustCall.is_rust_helpers_available()
        return false
    end
    lib = RustCall.get_rust_helpers_lib()
    if lib === nothing
        return false
    end
    # Check if the vec function exists
    try
        Libdl.dlsym(lib, :rust_vec_new_from_array_i32)
        return true
    catch
        return false
    end
end

@testset "Array and Collection Types" begin
    @testset "RustVec Indexing" begin
        # Create a RustVec with dummy pointer for testing
        # Note: This only tests Julia-side indexing logic, not actual Rust memory
        if !RustCall.is_rust_helpers_available()
            # Test with dummy pointer (will only test bounds checking and logic)
            # We can't actually read/write memory without Rust helpers
            vec = RustCall.RustVec{Int32}(Ptr{Cvoid}(UInt(0x1000)), UInt(5), UInt(10))

            @test length(vec) == 5
            @test !vec.dropped

            # Test bounds checking
            @test_throws BoundsError vec[0]
            @test_throws BoundsError vec[6]
            @test_throws BoundsError vec[-1]

            # Test dropped vector
            RustCall.drop!(vec)
            @test_throws ErrorException vec[1]
            @test_throws ErrorException vec[1] = 42
        else
            # When Rust helpers are available, we could test actual memory operations
            # For now, we'll skip these tests
            @test true  # Placeholder
        end
    end

    @testset "RustSlice Indexing" begin
        # Create a RustSlice with dummy pointer
        slice = RustCall.RustSlice{Int32}(Ptr{Int32}(UInt(0x2000)), UInt(5))

        @test length(slice) == 5

        # Test bounds checking
        @test_throws BoundsError slice[0]
        @test_throws BoundsError slice[6]
        @test_throws BoundsError slice[-1]
    end

    @testset "RustVec Iterator" begin
        if !RustCall.is_rust_helpers_available()
            # Test iterator interface (without actual memory access)
            vec = RustCall.RustVec{Int32}(Ptr{Cvoid}(UInt(0x1000)), UInt(3), UInt(10))

            # Test iterator traits
            @test Base.IteratorSize(RustCall.RustVec{Int32}) == Base.HasLength()
            @test Base.IteratorEltype(RustCall.RustVec{Int32}) == Base.HasEltype()
            @test Base.eltype(RustCall.RustVec{Int32}) == Int32

            # Test iterate function exists
            @test hasmethod(Base.iterate, Tuple{RustCall.RustVec{Int32}})
            @test hasmethod(Base.iterate, Tuple{RustCall.RustVec{Int32}, Int})
        else
            @test true  # Placeholder
        end
    end

    @testset "RustSlice Iterator" begin
        slice = RustCall.RustSlice{Int32}(Ptr{Int32}(UInt(0x2000)), UInt(3))

        # Test iterator traits
        @test Base.IteratorSize(RustCall.RustSlice{Int32}) == Base.HasLength()
        @test Base.IteratorEltype(RustCall.RustSlice{Int32}) == Base.HasEltype()
        @test Base.eltype(RustCall.RustSlice{Int32}) == Int32

        # Test iterate function exists
        @test hasmethod(Base.iterate, Tuple{RustCall.RustSlice{Int32}})
        @test hasmethod(Base.iterate, Tuple{RustCall.RustSlice{Int32}, Int})
    end

    @testset "RustVec to Vector Conversion" begin
        if !RustCall.is_rust_helpers_available()
            # Test conversion function exists
            vec = RustCall.RustVec{Int32}(Ptr{Cvoid}(UInt(0x1000)), UInt(5), UInt(10))

            # Test that Vector() and collect() functions exist
            @test hasmethod(Base.Vector, Tuple{RustCall.RustVec{Int32}})
            @test hasmethod(Base.collect, Tuple{RustCall.RustVec{Int32}})

            # Test that conversion fails gracefully for dropped vector
            RustCall.drop!(vec)
            @test_throws ErrorException Vector(vec)
            @test_throws ErrorException collect(vec)
        else
            @test true  # Placeholder
        end
    end

    @testset "Vector to RustVec Conversion" begin
        # Test that generic constructor exists (RustVec(v::Vector{T}) where T)
        @test hasmethod(RustCall.RustVec, Tuple{Vector{Int32}})
        @test hasmethod(RustCall.RustVec, Tuple{Vector{Int64}})
        @test hasmethod(RustCall.RustVec, Tuple{Vector{Float32}})
        @test hasmethod(RustCall.RustVec, Tuple{Vector{Float64}})

        # Test that it requires Rust helpers library
        if !RustCall.is_rust_helpers_available()
            julia_vec = Int32[1, 2, 3, 4, 5]
            @test_throws ErrorException RustCall.RustVec(julia_vec)
        elseif !is_vec_helpers_available()
            # Library loaded but Vec functions not available - need rebuild
            @warn "Rust helpers library loaded but Vec functions not available. Rebuild with: Pkg.build(\"RustCall\")"
            @test true  # Placeholder to pass
        else
            # When Rust helpers and Vec functions are available, test actual conversion
            @testset "RustVec from Vector{Int32}" begin
                julia_vec = Int32[1, 2, 3, 4, 5]
                rust_vec = RustCall.RustVec(julia_vec)

                @test length(rust_vec) == 5
                @test !rust_vec.dropped
                @test rust_vec.ptr != C_NULL

                # Test that we can access elements
                @test rust_vec[1] == 1
                @test rust_vec[5] == 5

                # Test conversion back to Julia
                back_to_julia = Vector(rust_vec)
                @test back_to_julia == julia_vec

                # Clean up
                RustCall.drop!(rust_vec)
                @test rust_vec.dropped
            end

            @testset "RustVec from Vector{Int64}" begin
                julia_vec = Int64[10, 20, 30]
                rust_vec = RustCall.RustVec(julia_vec)

                @test length(rust_vec) == 3
                @test rust_vec[1] == 10
                @test rust_vec[3] == 30

                RustCall.drop!(rust_vec)
            end

            @testset "RustVec from Vector{Float32}" begin
                julia_vec = Float32[1.5f0, 2.5f0, 3.5f0]
                rust_vec = RustCall.RustVec(julia_vec)

                @test length(rust_vec) == 3
                @test rust_vec[1] ≈ 1.5f0

                RustCall.drop!(rust_vec)
            end

            @testset "RustVec from Vector{Float64}" begin
                julia_vec = [1.5, 2.5, 3.5]
                rust_vec = RustCall.RustVec(julia_vec)

                @test length(rust_vec) == 3
                @test rust_vec[1] ≈ 1.5

                RustCall.drop!(rust_vec)
            end
        end
    end

    @testset "RustVec isbitstype validation" begin
        # isbits types should work
        @test_nowarn RustCall.RustVec{Int32}(C_NULL, UInt(0), UInt(0))
        @test_nowarn RustCall.RustVec{Float64}(C_NULL, UInt(0), UInt(0))

        # Non-isbits types should be rejected
        @test_throws ErrorException RustCall.RustVec{String}(C_NULL, UInt(0), UInt(0))
        @test_throws ErrorException RustCall.RustVec{Any}(C_NULL, UInt(0), UInt(0))
        @test_throws ErrorException RustCall.RustVec{Vector{Int}}(C_NULL, UInt(0), UInt(0))
    end

    @testset "RustVec Type Constructors" begin
        # Test generic constructor handles all supported types via type inference
        # The generic RustVec(v::Vector{T}) where T handles these automatically
        @test hasmethod(RustCall.RustVec, Tuple{Vector{Int32}})
        @test hasmethod(RustCall.RustVec, Tuple{Vector{Int64}})
        @test hasmethod(RustCall.RustVec, Tuple{Vector{Float32}})
        @test hasmethod(RustCall.RustVec, Tuple{Vector{Float64}})
    end

    # Full integration tests when Rust helpers library is available
    if RustCall.is_rust_helpers_available() && is_vec_helpers_available()
        @testset "RustVec Full Integration" begin
            @testset "create_rust_vec" begin
                # Int32
                julia_vec = Int32[1, 2, 3, 4, 5]
                rust_vec = RustCall.create_rust_vec(julia_vec)
                @test length(rust_vec) == 5
                @test !rust_vec.dropped
                RustCall.drop!(rust_vec)
                @test rust_vec.dropped

                # Int64
                julia_vec64 = Int64[10, 20, 30]
                rust_vec64 = RustCall.create_rust_vec(julia_vec64)
                @test length(rust_vec64) == 3
                RustCall.drop!(rust_vec64)

                # Float32
                julia_vecf32 = Float32[1.0f0, 2.0f0, 3.0f0]
                rust_vecf32 = RustCall.create_rust_vec(julia_vecf32)
                @test length(rust_vecf32) == 3
                RustCall.drop!(rust_vecf32)

                # Float64
                julia_vecf64 = [1.0, 2.0, 3.0]
                rust_vecf64 = RustCall.create_rust_vec(julia_vecf64)
                @test length(rust_vecf64) == 3
                RustCall.drop!(rust_vecf64)
            end

            @testset "RustVec finalizer calls Rust drop" begin
                rust_vec = RustCall.create_rust_vec(Int32[1, 2, 3])
                @test !rust_vec.dropped
                finalize(rust_vec)
                @test rust_vec.dropped
                @test rust_vec.ptr == C_NULL
            end

            @testset "rust_vec_get and rust_vec_set!" begin
                julia_vec = Int32[10, 20, 30, 40, 50]
                rust_vec = RustCall.create_rust_vec(julia_vec)

                # Test get (0-indexed)
                @test RustCall.rust_vec_get(rust_vec, 0) == 10
                @test RustCall.rust_vec_get(rust_vec, 2) == 30
                @test RustCall.rust_vec_get(rust_vec, 4) == 50

                # Test bounds error
                @test_throws BoundsError RustCall.rust_vec_get(rust_vec, 5)
                @test_throws BoundsError RustCall.rust_vec_get(rust_vec, -1)

                # Test set (0-indexed)
                @test RustCall.rust_vec_set!(rust_vec, 0, Int32(100))
                @test RustCall.rust_vec_get(rust_vec, 0) == 100

                @test RustCall.rust_vec_set!(rust_vec, 4, Int32(500))
                @test RustCall.rust_vec_get(rust_vec, 4) == 500

                RustCall.drop!(rust_vec)
            end

            @testset "copy_to_julia!" begin
                julia_vec = Int32[1, 2, 3, 4, 5]
                rust_vec = RustCall.create_rust_vec(julia_vec)

                # Copy to exact-size array
                dest = Vector{Int32}(undef, 5)
                copied = RustCall.copy_to_julia!(rust_vec, dest)
                @test copied == 5
                @test dest == julia_vec

                # Copy to smaller array
                small_dest = Vector{Int32}(undef, 3)
                copied_small = RustCall.copy_to_julia!(rust_vec, small_dest)
                @test copied_small == 3
                @test small_dest == Int32[1, 2, 3]

                # Copy to larger array (only fills first 5)
                large_dest = Vector{Int32}(undef, 10)
                fill!(large_dest, Int32(0))
                copied_large = RustCall.copy_to_julia!(rust_vec, large_dest)
                @test copied_large == 5
                @test large_dest[1:5] == julia_vec
                @test large_dest[6:10] == zeros(Int32, 5)

                RustCall.drop!(rust_vec)
            end

            @testset "to_julia_vector" begin
                julia_vec = Int32[100, 200, 300]
                rust_vec = RustCall.create_rust_vec(julia_vec)

                result = RustCall.to_julia_vector(rust_vec)
                @test result == julia_vec
                @test typeof(result) == Vector{Int32}

                RustCall.drop!(rust_vec)
            end

            @testset "push!" begin
                julia_vec = Int32[1, 2, 3]
                rust_vec = RustCall.create_rust_vec(julia_vec)

                @test length(rust_vec) == 3

                # Push elements
                push!(rust_vec, Int32(4))
                @test length(rust_vec) == 4

                push!(rust_vec, Int32(5))
                @test length(rust_vec) == 5

                # Verify contents
                result = RustCall.to_julia_vector(rust_vec)
                @test result == Int32[1, 2, 3, 4, 5]

                RustCall.drop!(rust_vec)
            end

            @testset "Multiple Types Operations" begin
                # Int64
                vec64 = RustCall.create_rust_vec(Int64[100, 200, 300])
                @test RustCall.rust_vec_get(vec64, 1) == 200
                RustCall.rust_vec_set!(vec64, 1, Int64(999))
                @test RustCall.rust_vec_get(vec64, 1) == 999
                RustCall.drop!(vec64)

                # Float32
                vecf32 = RustCall.create_rust_vec(Float32[1.5f0, 2.5f0])
                @test RustCall.rust_vec_get(vecf32, 0) ≈ 1.5f0
                push!(vecf32, Float32(3.5))
                @test length(vecf32) == 3
                RustCall.drop!(vecf32)

                # Float64
                vecf64 = RustCall.create_rust_vec([1.1, 2.2, 3.3])
                @test RustCall.rust_vec_get(vecf64, 2) ≈ 3.3
                result = RustCall.to_julia_vector(vecf64)
                @test result ≈ [1.1, 2.2, 3.3]
                RustCall.drop!(vecf64)
            end

            @testset "Memory Safety" begin
                # Create and drop many vectors
                for i in 1:100
                    v = RustCall.create_rust_vec(Int32[i, i+1, i+2])
                    @test length(v) == 3
                    RustCall.drop!(v)
                    @test v.dropped
                end

                # Test error on dropped vec operations
                v = RustCall.create_rust_vec(Int32[1, 2, 3])
                RustCall.drop!(v)
                @test_throws ErrorException RustCall.rust_vec_get(v, 0)
                @test_throws ErrorException RustCall.rust_vec_set!(v, 0, Int32(1))
                @test_throws ErrorException RustCall.to_julia_vector(v)
            end
        end
    end
end
