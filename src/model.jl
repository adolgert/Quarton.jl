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
function add_queue_edge!(g::MutableBiGraph, s, q)
    if s ∉ keys(g.queue)
        g.server[s] = Int[q]
    else
        push!(g.queue[s], q)
    end
end
outqueues(g::MutableBiGraph, s) = g.server[s]
outservers(g::MutableBiGraph, q) = g.queue[q]

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
        resize!(m.server_tokens, length(m.server))
        resize!(m.server_available, length(m.server))
        m.server_available .= true
        m.network = BiGraph(length(m.server), length(m.queue))
        m.built = true
    end
end

function connect!(m::QueueModel, q::Queue, s::Server, role::Symbol)
    ensure_built!(m)
    qid = findfirst(isequal(q), m.queue)
    sid = findfirst(isequal(s), m.server)
    add_queue_edge!(m.network, qid, sid)
    m.server_role[(qid, sid)] = role
end

function connect!(m::QueueModel, s::Server, q::Queue, role::Symbol)
    ensure_built!(m)
    sid = findfirst(isequal(s), m.server)
    qid = findfirst(isequal(q), m.queue)
    add_server_edge!(m.network, sid, qid)
    m.queue_role[(sid, qid)] = role
end


function check_model(m::QueueModel)
    equivalent_graph = single_graph(m.network)
    @assert is_weakly_connected(equivalent_graph)
    for server_id in eachindex(m.server)
        @assert length(inqueues(m.network, server_id)) == 1
    end
end
