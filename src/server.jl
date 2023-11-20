using Distributions
using Fleck
using Random

# This is a Queueing model. There are queues that accept job tokens
# and choose the next one. There are servers that take tokens and process
# them for a random time.
#
# Every server reads from exactly one queue.
# A server can send jobs to multiple queues.
# Multiple servers can get jobs from the same queue.

abstract type Server end

export Server, ArrivalServer, ModifyServer

mutable struct ModifyServer <: Server
    rate::Float64
    modify_token::Function
    disbursement::Assignment
    id::Int
end


function ModifyServer(rate::Float64; disbursement=nothing)
    if disbursement === nothing
        disbursement = RoundRobin()
    end
    ModifyServer(rate, identity, disbursement, zero(Int))
end

id!(s::ModifyServer, id::Int) = (s.id = id; s)
id(s::ModifyServer) = s.id

rate(s::ModifyServer, token) = Exponential(workload(token) / s.rate)
modify!(s::ModifyServer, token, when) = (s.modify_token(token); nothing)


function update_downstream!(s::ModifyServer, downstream, when, rng)
    update_downstream!(s.disbursement, downstream, when, rng)
end


"""
If you need an arrival rate of tokens, make an InfiniteQueue of tokens
and feed it to this ArrivalServer. This will create tokens at the needed
rate.
"""
mutable struct ArrivalServer <: Server
    rate::Float64
    disbursement::Assignment
    id::Int
end

function ArrivalServer(rate::Float64; disbursement=nothing)
    if disbursement === nothing
        disbursement = RoundRobin()
    end
    ArrivalServer(rate, disbursement, zero(Int))
end

id!(s::ArrivalServer, id::Int) = (s.id = id; s)
id(s::ArrivalServer) = s.id

rate(s::ArrivalServer, token) = Exponential(workload(token) / s.rate)
modify!(s::ArrivalServer, token, when) = create!(token, when)


function update_downstream!(s::ArrivalServer, downstream, when, rng)
    update_downstream!(s.disbursement, downstream, when, rng)
end
