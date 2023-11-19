using Distributions
using Random
using Fleck

export Trajectory, next


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
