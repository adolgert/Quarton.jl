using Test

@testset "Run simple machine" begin
    model = QueueModel()
    s1 = ModifyServer(1.0)
    source = InfiniteSourceQueue()
    @pipe! model source => s1 :only
    sink = SinkQueue()
    @pipe! model s1 => sink :only
    check_model(model)
    trajectory = Trajectory(2342334)
    start_time = zero(Float64)
    activate!(model, trajectory, s1, Work())
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
    source = InfiniteSourceQueue()
    fifo = FIFOQueue()
    sink = SinkQueue()
    s1 = ModifyServer(1.0)
    s2 = ModifyServer(1.0)
    @pipe! model source => s1 :only
    @pipe! model s1 => fifo :only
    @pipe! model fifo => s2 :only
    @pipe! model s2 => sink :only
    check_model(model)
    trajectory = Trajectory(2342334)
    start_time = zero(Float64)
    activate!(model, trajectory, s1, Work())
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
