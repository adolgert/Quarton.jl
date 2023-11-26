
@testset "MutableBiGraph smoke" begin
    g = Quarton.MutableBiGraph()
    Quarton.add_server_edge!(g, 3, 17)
    Quarton.add_server_edge!(g, 3, 18)
    Quarton.add_queue_edge!(g, 4, 26)
    Quarton.add_queue_edge!(g, 5, 29)
    @test Quarton.server_length(g) == 3
    @test Quarton.queue_length(g) == 4
end
