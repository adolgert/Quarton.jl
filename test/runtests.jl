using Test
using Quarton

@testset "server" begin
    include("test_server.jl")
end

@testset "machine" begin
    include("test_machine.jl")
end
