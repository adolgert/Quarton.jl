using Test

@testset "Build one" begin
    model = QueueModel()
    source = InfiniteQueue()
    sink = SinkQueue()
    s1 = Server(1.0)
    add_queue!(model, source)
    add_queue!(model, sink)
    add_server!(model, s1)
    connect!(model, source, s1, :only)
    connect!(model, s1, sink, :only)
    trajectory = Trajectory(2342334)
    activate!(model, trajectory, s1, Work())
    for i in 1:100
        when, which = next(trajectory)
        @test isfinite(when)
        step!(model, trajectory, (when, which))
    end
end
