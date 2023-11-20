using Test

@testset "Run simple machine" begin
    model = QueueModel()
    source = InfiniteSourceQueue()
    sink = SinkQueue()
    s1 = ModifyServer(1.0)
    add_queue!(model, source)
    add_queue!(model, sink)
    add_server!(model, s1)
    connect!(model, source, s1, :only)
    connect!(model, s1, sink, :only)
    check_model(model)
    trajectory = Trajectory(2342334)
    start_time = zero(Float64)
    activate!(model, trajectory, s1, Work(start_time))
    for i in 1:100
        when, which = next(trajectory)
        @test isfinite(when)
        step!(model, trajectory, (when, which))
    end
    println("created $(source.create_cnt)")
    println("retired $(sink.retire_cnt)")
    throughput = sink.retire_cnt / sink.retire_total_duration
    println("throughput $throughput")
end



@testset "Machine with FIFO" begin
    model = QueueModel()
    source = add_queue!(model, InfiniteSourceQueue())
    fifo = add_queue!(model, FIFOQueue())
    sink = add_queue!(model, SinkQueue())
    s1 = add_server!(model, ModifyServer(1.0))
    s2 = add_server!(model, ModifyServer(1.0))
    connect!(model, source, s1, :only)
    connect!(model, s1, fifo, :only)
    connect!(model, fifo, s2, :only)
    connect!(model, s2, sink, :only)
    check_model(model)
    trajectory = Trajectory(2342334)
    start_time = zero(Float64)
    activate!(model, trajectory, s1, Work(start_time))
    for i in 1:100
        when, which = next(trajectory)
        @test isfinite(when)
        step!(model, trajectory, (when, which))
    end
    @test source.create_cnt > 0
    println("fifo size $(length(fifo.deque))")
    @test fifo.retire_cnt > 0
    @test sink.retire_cnt > 0
    println("created $(source.create_cnt)")
    println("fifo retired $(fifo.retire_cnt)")
    println("retired $(sink.retire_cnt)")
    throughput = sink.retire_cnt / sink.retire_total_duration
    println("throughput $throughput")
end
