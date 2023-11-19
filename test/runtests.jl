using Test
using quarton

@testset "server" begin
    include("test_server.jl")
end

@testset "machine" begin
    include("test_machine.jl")
end
