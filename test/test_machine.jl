using Test
using DataStructures
using Distributions
using GraphPlot, Compose, Colors
import Cairo, Fontconfig

@testset "Run simple machine" begin
    T = Work
    model = QueueModel{T}()
    s1 = ModifyServer(1.0)
    source = InfiniteSourceQueue{T}()
    @pipe! model source => s1 :only
    sink = SummarySink{T}()
    @pipe! model s1 => sink :only
    check_model(model)
    trajectory = Trajectory(2342334)
    start_time = zero(Float64)
    activate!(model, trajectory, s1, T())
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
    T = Work
    model = QueueModel{T}()
    source = InfiniteSourceQueue{T}()
    fifo = FIFOQueue{T}()
    sink = SummarySink{T}()
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


@testset "Task assignment farm" begin
    function gamma_k(job_variability)
        kmax = 20
        kmin = 1.001
        return 1.0 + (kmin - kmax) * (job_variability - 1.0)
    end
    
    function task_assignment_server_farm(
        arrival_rate, service_rate, job_variability, N=10
        )
        k = gamma_k(job_variability)
        T = Work
        work_dist = (when, rng) -> Work(rand(rng, Gamma(k, 1/k)), when)
        model = QueueModel{T}()
        source = InfiniteSourceQueue{T}(work_dist)
        fifo = FIFOQueue{T}()
        sink = SummarySink{T}()
        assign_strategy = LeastWorkLeft()
        s1 = ArrivalServer(arrival_rate, disbursement=assign_strategy)
        servers = Vector{ModifyServer}(undef, N)
        for s_create_idx in 1:N
            servers[s_create_idx] = ModifyServer(service_rate)
        end
        @pipe! model source => s1 :only
        @pipe! model s1 => fifo :only
        for s_connect_idx in 1:N
            @pipe! model fifo => servers[s_connect_idx] gensym()
            @pipe! model servers[s_connect_idx] => sink :only
        end
        check_model(model)

        graph, labels, membership = network(model)
        @test Set(membership) == Set([1, 2])
        nodecolor = [colorant"lightseagreen", colorant"orange"]
        p = gplot(graph, nodelabel=labels, nodefillc=nodecolor[membership])
        draw(PNG("server_farm.png", 26cm, 26cm), p)

        trajectory = Trajectory(2342334)
        start_time = zero(Float64)
        activate!(model, trajectory, s1, T())
        when = 0.0
        cnt = 0
        while cnt < 10000 && when < 100.0
            when, which = next(trajectory)
            step!(model, trajectory, (when, which))
            cnt += 1
        end
        response = sink.retire_total_duration / sink.retire_cnt
        return response
    end
    r = task_assignment_server_farm(10.0, 1.0, 0.2, 10)
    @test r > 2.0
    @test r < 3.0
end
