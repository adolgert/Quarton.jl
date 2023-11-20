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

export Server


mutable struct Server
    rate::UnivariateDistribution
    modify_token::Function
    disbursement::Disbursement
    id::Int
end

function Server(rate::Float64)
    Server(Exponential(rate), identity, RoundRobin(), zero(Int))
end

id!(s::Server, id::Int) = (s.id = id; s)
id(s::Server) = s.id

rate(s::Server, token) = s.rate
modify!(s::Server, token, when) = (s.modify_token(token); nothing)


function update_downstream!(s::Server, downstream, when, rng)
    update_downstream!(s.disbursement, downstream, when, rng)
end


"""
If you need an arrival rate of tokens, make an InfiniteQueue of tokens
and feed it to this ArrivalServer. This will create tokens at the needed
rate.
"""
mutable struct ArrivalServer
    rate::UnivariateDistribution
    disbursement::Disbursement
    id::Int
end

function ArrivalServer(rate::Float64)
    ArrivalServer(Exponential(rate), identity, RoundRobin(), zero(Int))
end

id!(s::ArrivalServer, id::Int) = (s.id = id; s)
id(s::ArrivalServer) = s.id

rate(s::ArrivalServer, token) = s.rate
modify!(s::ArrivalServer, token, when) = create!(token, when)


function update_downstream!(s::ArrivalServer, downstream, when, rng)
    update_downstream!(s.disbursement, downstream, when, rng)
end
