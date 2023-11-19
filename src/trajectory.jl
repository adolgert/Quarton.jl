using Distributions
using Random
using Fleck

export Trajectory, next


mutable struct Trajectory
    sampler::Fleck.SSA{Int,Float64}
    time::Float64
    rng::Xoshiro
    last_event::Int
    modified_servers::Set{Int}
    modified_queues::Set{Int}
end

function Trajectory(rng_seed=23947234)
    sampler = Fleck.FirstToFire{Int,Float64}()
    Trajectory(sampler, 0.0, Xoshiro(rng_seed), zero(Int), Set{Int}(), Set{Int}())
end


function stop!(t::Trajectory, server_id, time)
    Fleck.disable!(t.sampler, server_id, time)
    empty!(t.modified_servers)
    empty!(t.modified_queues)
    t.time = time
    t.last_event = server_id
end


function start!(t::Trajectory, server, rate::UnivariateDistribution)
    Fleck.enable!(t.sampler, server, rate, t.time, t.time, t.rng)
end

next(t::Trajectory) = Fleck.next(t.sampler, t.time, t.rng)

"""
This enables tracking of what happened during an event.
"""
function modify_server_and_queue!(t::Trajectory, server_id, queue_id)
    push!(t.modified_servers, server_id)
    push!(t.modified_queues, queue_id)
end
