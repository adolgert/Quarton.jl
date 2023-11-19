export RoundRobin

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


function update_downstream!(r::RoundRobin, downstream, when, rng)
    q_dest = queues(downstream)
    push!(downstream, q_dest[r.next], when)
    r.next = mod1(r.next + 1, length(q_dest))
    return q_dest[r.next]
end
