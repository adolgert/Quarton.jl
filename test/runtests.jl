using Test

@testset "queuesystem" begin
    include("test_queuesystem.jl")
end

@testset "queue" begin
    include("test_queue.jl")
end

# @testset "server" begin
#     include("test_server.jl")
# end

# @testset "model" begin
#     include("test_model.jl")
# end

# @testset "machine" begin
#     include("test_machine.jl")
# end

# @testset "plot" begin
#     include("test_plot.jl")
# end
