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
