using GraphPlot, Compose, Colors
import Cairo, Fontconfig


@testset "Plotting Start" begin
    arrival_rate = 1.0
    service_rate = 1.0
    model = QueueModel()
    token_builder = (when, rng) -> CountedWork(1.0, when)
    source = InfiniteSourceQueue(token_builder)
    arrival = ArrivalServer(arrival_rate)
    connect!(model, source, arrival, :only)
    CPU_queue = FIFOQueue()
    connect!(model, arrival, CPU_queue, :only)
    CPU = ModifyServer(service_rate)
    connect!(model, CPU_queue, CPU, :only)

    disk1_queue = FIFOQueue()
    connect!(model, CPU, disk1_queue, :only)

    on_output = token -> (token.mark = 2; nothing)
    assign_by_mark = SizeIntervalAssignment(t -> (t.mark == 1) ? :around : :out)
    disk1 = ModifyServer(
        service_rate, disbursement=assign_by_mark, modify=on_output
        )
    connect!(model, disk1_queue, disk1, :only)

    sink = SinkQueue()
    connect!(model, disk1, sink, :out)
    
    disk2_queue = FIFOQueue()
    connect!(model, disk1, disk2_queue, :around)

    disk2 = ModifyServer(service_rate)
    connect!(model, disk2_queue, disk2, :only)
    connect!(model, disk2, disk1_queue, :only)
    check_model(model)

    graph, labels, membership = Quarton.single_graph(model.network)
    @test Set(membership) == Set([1, 2])
    nodecolor = [colorant"lightseagreen", colorant"orange"]
    p = gplot(graph, nodelabel=labels, nodefillc=nodecolor[membership])
    draw(PNG("plot_start.png", 16cm, 16cm), p)
end
