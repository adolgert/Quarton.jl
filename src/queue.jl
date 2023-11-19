
using DataStructures

export Queue, InfiniteQueue, FIFOQueue, SinkQueue

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
