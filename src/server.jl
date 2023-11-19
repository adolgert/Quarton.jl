using Distributions
using DataStructures
using Graphs
using Fleck
using Random

# This is a Queueing model. There are queues that accept job tokens
# and choose the next one. There are servers that take tokens and process
# them for a random time.
#
# Every server reads from exactly one queue.
# A server can send jobs to multiple queues.
# Multiple servers can get jobs from the same queue.

export InfiniteQueue, QueueModel, SinkQueue, Server, Work, Trajectory
export add_queue!, add_server!, connect!, step!, activate!, next

abstract type Token end

struct Work <: Token
end

"""
Accepts tokens and chooses next one.
"""

abstract type Disbursement end
# Any, RoundRobin, Random, ByTokenType, ByTokenValue


mutable struct RoundRobin <: Disbursement
    next::Int
    role::Vector{Symbol}
    RoundRobin() = new(1, Symbol[])
end


function destination!(r::RoundRobin, queue_dict, token)
    if length(r.role) < length(queue_dict)
        r.role = collect(keys(queue_dict))
    end
    n = r.next
    r.next = mod1(r.next + 1, length(queue_dict))
    return r.role[n]
end


abstract type Queue end

struct FIFOQueue <: Queue
    deque::Deque{Token}
end

Base.push!(q::FIFOQueue, token) = push!(q.deque, token)

function get_token!(q::FIFOQueue, server, server_role)
    if !isempty(q.deque)
        token = popfirst!(q.deque)
        return token
    end
    return nothing
end


struct InfiniteQueue <: Queue end
get_token!(q::InfiniteQueue, server, server_role) = Work()

struct SinkQueue <: Queue end
Base.push!(q::SinkQueue, token) = nothing


struct Server
    rate::UnivariateDistribution
    modify_token::Function
    disbursement::Disbursement
end

function Server(rate::Float64)
    Server(Exponential(rate), identity, RoundRobin())
end

set_rate!(s::Server, rate::Float64) = (s.rate = Exponential(rate); nothing)
set_rate!(s::Server, rate::UnivariateDistribution) = (s.rate = rate; nothing)
rate(s::Server, token) = s.rate
modify!(s::Server, token) = (s.modify_token(token); nothing)

function destination!(s::Server, queue_dict, token)
    return destination!(s.disbursement, queue_dict, token)
end


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


mutable struct Trajectory
    sampler::Fleck.SSA{Int,Float64}
    time::Float64
    rng::Xoshiro
end

function Trajectory(rng_seed=23947234)
    sampler = Fleck.FirstToFire{Int,Float64}()
    Trajectory(sampler, 0.0, Xoshiro(rng_seed))
end


function stop!(t::Trajectory, server_id, time)
    Fleck.disable!(t.sampler, server_id, time)
    t.time = time
end


function start!(t::Trajectory, server, rate::UnivariateDistribution)
    Fleck.enable!(t.sampler, server, rate, t.time, t.time, t.rng)
end

next(t::Trajectory) = Fleck.next(t.sampler, t.time, t.rng)

function activate!(model::QueueModel, trajectory, server, token)
    s_id = findfirst(isequal(server), model.server)
    model.server_tokens[s_id] = token
    start!(trajectory, s_id, rate(server, token))
    model.server_available[s_id] = false
end


# Starting state is just before server produces token.
# Ending state is just after, when the token is where it goes
# and this server and/or another server may have started.
#
# Note on variable names:
#   An initial s is for server and q is for queue.
#   A final _id is the index into the model's values.
#   A final _role means it's the role tag.
function step!(model, trajectory, (when, s_event_id))
    # First take the token from the server that just completed work.
    stop!(trajectory, s_event_id, when)
    s_event = model.server[s_event_id]
    event_token = model.server_tokens[s_event_id]
    modify!(s_event, event_token)
    model.server_available[s_event_id] = true

    # That event_token will go to one of the queues waiting for it.
    q_receive_ids = outqueues(model.network, s_event_id)
    # All this setup making temporary dictionaries is meant to allow users'
    # code to focus on outgoing queues and their roles.
    q_receive_dict = Dict{Symbol,Queue}()
    role_to_id = Dict{Symbol,Int}()
    for q_id in q_receive_ids
        role = model.queue_role[(s_event_id, q_id)]
        q_receive_dict[role] = model.queue[q_id]
        role_to_id[role] = q_id
    end
    q_dest_sym = destination!(s_event, q_receive_dict, event_token)
    q_dest_id = role_to_id[q_dest_sym]
    q_dest = model.queue[q_dest_id]
    push!(q_dest, event_token)

    # Changing the receiving queue could start waiting servers.
    server_ids = outservers(model.network, q_dest_id)
    push!(server_ids, s_event_id)  # The original server could start again.

    for s_ready_id in server_ids
        if model.server_available[s_ready_id]
            # There is exactly one input queue for each server.
            q_only_id = inqueues(model.network, s_ready_id)[1]
            s_ready_role = model.server_role[(q_only_id, s_ready_id)]
            s_ready = model.server[s_ready_id]
            take_token = get_token!(model.queue[q_only_id], s_ready, s_ready_role)
            if take_token !== nothing
                fire_rate = rate(model.server[s_ready_id], take_token)
                start!(trajectory, s_ready_id, fire_rate)
                model.server_tokens[s_ready_id] = take_token
                model.server_available[s_ready_id] = false
            end
        end
    end
end
