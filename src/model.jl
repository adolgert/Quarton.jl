using Logging

using Graphs

export QueueModel
export add_queue!, add_server!, connect!, step!, check_model

struct BiGraph
    server::SimpleDiGraph{Int}
    queue::SimpleDiGraph{Int}
    server_cnt::Int
    queue_cnt::Int
    function BiGraph(scnt, qcnt)
        n = max(scnt, qcnt)
        new(SimpleDiGraph{Int}(n), SimpleDiGraph{Int}(n), scnt, qcnt)
    end
end

add_server_edge!(g::BiGraph, s, q) = add_edge!(g.server, s, q)
add_queue_edge!(g::BiGraph, q, s) = add_edge!(g.queue, q, s)
inqueues(g::BiGraph, s) = inneighbors(g.queue, s)
outqueues(g::BiGraph, s) = outneighbors(g.server, s)
inservers(g::BiGraph, q) = inneighbors(g.server, q)
outservers(g::BiGraph, q) = outneighbors(g.queue, q)


struct MutableBiGraph
    server::Dict{Int,Vector{Int}}
    queue::Dict{Int,Vector{Int}}
    MutableBiGraph() = new(Dict{Int,Vector{Int}}(), Dict{Int,Vector{Int}}())
end

function add_server_edge!(g::MutableBiGraph, s, q)
    if s ∉ keys(g.server)
        g.server[s] = Int[q]
    else
        push!(g.server[s], q)
    end
end
function add_queue_edge!(g::MutableBiGraph, q, s)
    if q ∉ keys(g.queue)
        g.queue[s] = Int[s]
    else
        push!(g.queue[q], s)
    end
end
outqueues(g::MutableBiGraph, s) = (s ∈ keys(g.server)) ?  g.server[s] : Vector{Int}()
outservers(g::MutableBiGraph, q) = (q ∈ keys(g.queue)) ?  g.queue[q] : Vector{Int}()

function server_length(g::MutableBiGraph)
    servers = Set(keys(g.server))
    for targets in values(g.queue)
        union!(servers, targets)
    end
    return length(servers)
end

function queue_length(g::MutableBiGraph)
    queues = Set(keys(g.queue))
    for targets in values(g.server)
        union!(queues, targets)
    end
    return length(queues)
end


"""
In order to check graph properties, convert the bigraph into a single
directed graph where the first N nodes are servers and the next N
nodes are queues.
"""
function single_graph(bigraph::BiGraph)
    s = SimpleDiGraph{Int}(bigraph.server_cnt + bigraph.queue_cnt)
    for edge in edges(bigraph.server)
        add_edge!(s, src(edge), bigraph.server_cnt + dst(edge))
    end
    for edge in edges(bigraph.queue)
        add_edge!(s, bigraph.server_cnt + src(edge), dst(edge))
    end
    return s
end


mutable struct QueueModel
    network::BiGraph
    server_role::Dict{Tuple{Int,Int},Symbol} # what a server means to a queue
    queue_role::Dict{Tuple{Int,Int},Symbol}
    server::Vector{Server}
    server_available::Vector{Bool}
    server_tokens::Vector{Token}
    queue::Vector{Queue}
    build_network::MutableBiGraph
    built::Bool
end


function QueueModel()
    QueueModel(
        BiGraph(0, 0),
        Dict{Tuple{Int,Int},Symbol}(),
        Dict{Tuple{Int,Int},Symbol}(),
        Vector{Server}(),
        Vector{Bool}(),
        Vector{Token}(),
        Vector{Queue}(),
        MutableBiGraph(),
        false
        )
end

function add_server!(m::QueueModel, server)
    push!(m.server, server)
    id!(server, length(m.server))
    return server
end

function add_queue!(m::QueueModel, queue)
    push!(m.queue, queue)
    id!(queue, length(m.queue))
    queue
end

function ensure_built!(m::QueueModel)
    if !m.built
        @debug "Bulding queueing model"
        resize!(m.server_tokens, length(m.server))
        resize!(m.server_available, length(m.server))
        m.server_available .= true
        m.network = BiGraph(length(m.server), length(m.queue))
        for s_source in eachindex(m.server)
            for q_target in outqueues(m.build_network, s_source)
                add_server_edge!(m.network, s_source, q_target)
            end
        end
        for q_source in eachindex(m.queue)
            for s_target in outservers(m.build_network, q_source)
                add_queue_edge!(m.network, q_source, s_target)
            end
        end
        # Erase it because we don't need that memory hanging around.
        m.build_network = MutableBiGraph()
        m.built = true
    end
    nothing
end


function connect!(m::QueueModel, q::Queue, s::Server, role::Symbol)
    if q.id == 0
        add_queue!(m, q)
        @assert q.id > 0
    end
    if s.id == 0
        add_server!(m, s)
        @assert s.id > 0
    end
    add_queue_edge!(m.build_network, q.id, s.id)
    m.server_role[(q.id, s.id)] = role
end

function connect!(m::QueueModel, s::Server, q::Queue, role::Symbol)
    if q.id == 0
        add_queue!(m, q)
        @assert q.id > 0
    end
    if s.id == 0
        add_server!(m, s)
        @assert s.id > 0
    end
    add_server_edge!(m.build_network, s.id, q.id)
    m.queue_role[(s.id, q.id)] = role
end


function check_model(m::QueueModel)
    ensure_built!(m)
    equivalent_graph = single_graph(m.network)
    @assert is_weakly_connected(equivalent_graph)
    for server_id in eachindex(m.server)
        if length(inqueues(m.network, server_id)) != 1
            cnt = length(inqueues(m.network, server_id))
            println("Server $server_id has $cnt input queues")
            @assert length(inqueues(m.network, server_id)) == 1
        end
    end
end
