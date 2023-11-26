using Test
using Quarton

@testset "server" begin
    include("test_server.jl")
end

@testset "model" begin
    include("test_model.jl")
end

@testset "machine" begin
    include("test_machine.jl")
end

@testset "plot" begin
    include("test_plot.jl")
end
