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


function destination!(r::RoundRobin, queue_dict, token)
    if length(r.role) < length(queue_dict)
        r.role = collect(keys(queue_dict))
    end
    n = r.next
    r.next = mod1(r.next + 1, length(queue_dict))
    return r.role[n]
end
