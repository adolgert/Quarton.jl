using Graphs

export QueueModel
export add_queue!, add_server!, connect!, step!

struct BiGraph
    server::SimpleDiGraph{Int}
    queue::SimpleDiGraph{Int}
    BiGraph(n::Int) = new(SimpleDiGraph{Int}(n), SimpleDiGraph{Int}(n))
end

add_server_edge!(g::BiGraph, s, q) = add_edge!(g.server, s, q)
add_queue_edge!(g::BiGraph, q, s) = add_edge!(g.queue, q, s)
inqueues(g::BiGraph, s) = inneighbors(g.queue, s)
outqueues(g::BiGraph, s) = outneighbors(g.server, s)
inservers(g::BiGraph, q) = inneighbors(g.server, q)
outservers(g::BiGraph, q) = outneighbors(g.queue, q)


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
        BiGraph(0),
        Dict{Tuple{Int,Int},Symbol}(),
        Dict{Tuple{Int,Int},Symbol}(),
        Vector{Server}(),
        Vector{Bool}(),
        Vector{Token}(),
        Vector{Queue}(),
        false
        )
end

add_server!(m::QueueModel, server) = (push!(m.server, server); server)
add_queue!(m::QueueModel, queue) = (push!(m.queue, queue); queue)

function ensure_built!(m::QueueModel)
    if !m.built
        resize!(m.server_tokens, length(m.server))
        resize!(m.server_available, length(m.server))
        node_cnt = max(length(m.server), length(m.queue))
        m.network = BiGraph(node_cnt)
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

