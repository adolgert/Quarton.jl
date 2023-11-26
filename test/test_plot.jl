using GraphPlot, Compose, Colors
using EzXML
import Cairo, Fontconfig


@testset "Plotting Start" begin
    arrival_rate = 1.0
    service_rate = 1.0
    T = CountedWork
    model = QueueModel{T}()
    token_builder = (when, rng) -> T(1.0, when)
    source = InfiniteSourceQueue{T}(token_builder)
    arrival = ArrivalServer(arrival_rate)
    @pipe! model source => arrival :only
    CPU_queue = FIFOQueue{T}()
    @pipe! model arrival => CPU_queue :only
    CPU = ModifyServer(service_rate)
    @pipe! model CPU_queue => CPU :only

    disk1_queue = FIFOQueue{T}()
    @pipe! model CPU => disk1_queue :only

    on_output = token -> (token.mark = 2; nothing)
    assign_by_mark = SizeIntervalAssignment(t -> (t.mark == 1) ? :around : :out)
    disk1 = ModifyServer(
        service_rate, disbursement=assign_by_mark, modify=on_output
        )
    @pipe! model disk1_queue => disk1 :only

    sink = SinkQueue{T}()
    @pipe! model disk1 => sink :out
    
    disk2_queue = FIFOQueue{T}()
    @pipe! model disk1 => disk2_queue :around

    disk2 = ModifyServer(service_rate)
    @pipe! model disk2_queue => disk2 :only
    @pipe! model disk2 => disk1_queue :only
    check_model(model)

    graph, labels, membership = Quarton.single_graph(model.network)
    @test Set(membership) == Set([1, 2])
    nodecolor = [colorant"lightseagreen", colorant"orange"]
    p = gplot(graph, nodelabel=labels, nodefillc=nodecolor[membership])
    draw(PNG("plot_start.png", 16cm, 16cm), p)
end


@testset "Read from Inkscape" begin
    # This test shows how to make a drawing of a network of queues
    # and read it into the package. Inkscape saves as SVG with annotations.
    # If you make a drawing, right-click on each queue and server,
    # open the object properties, and set the label of queues to "queue"
    # and of servers to "server". Then this can read the SVG for the
    # network and names.
    doc = parsexml(read(open("test/queue2.svg", "r")))
    r = root(doc)
    graph = nothing
    for top in eachelement(r)
        if nodename(top) == "g"
            graph = top
        end
    end
    q_id = Vector{String}()
    s_id = Vector{String}()
    connect = Vector{Tuple{String,String}}()
    names = Dict{String,String}()

    tag_match = r"url\(\#([a-z0-9\-]+)\)"
    for child in eachelement(graph)
        if haskey(child, "inkscape:label") && child["inkscape:label"] == "queue"
            push!(q_id, child["id"])
        elseif haskey(child, "inkscape:label") && child["inkscape:label"] == "server"
            push!(s_id, child["id"])
        elseif nodename(child) == "path"
            # Strip the leading hash.
            source = child["inkscape:connection-start"][2:end]
            target = child["inkscape:connection-end"][2:end]
            push!(connect, (source, target))
        elseif nodename(child) == "text"
            style = child["style"]
            m = match(tag_match, style)
            if m !== nothing
                target = m.captures[1]
                names[target] = nodecontent(child)
            end
        end
    end
    @test length(q_id) == 3
    @test length(s_id) == 2
    @test length(connect) == 4
    @test length(names) == 5
end