
using DataStructures

export Queue, InfiniteQueue, FIFOQueue, SinkQueue

abstract type Queue end

mutable struct FIFOQueue <: Queue
    deque::Deque{Tuple{Token,Time}}
    retire_cnt::Int
    retire_total_duration::Time
    FIFOQueue() = new(Deque{Tuple{Token,Time}}(), zero(Int), zero(Time))
end

Base.push!(q::FIFOQueue, token, when) = push!(q.deque, (token, when))

function get_token!(q::FIFOQueue, server, server_role, when)
    if !isempty(q.deque)
        token, emplace_time = popfirst!(q.deque)
        q.retire_cnt += 1
        q.retire_total_duration += when - emplace_time
        return token
    end
    return nothing
end

throughput(q::FIFOQueue) = q.retire_cnt / q.retire_total_duration

mutable struct InfiniteQueue <: Queue
    create_cnt::Int
    InfiniteQueue() = new(zero(Int))
end

function get_token!(q::InfiniteQueue, server, server_role, when)
    q.create_cnt += 1
    Work(when)
end


mutable struct SinkQueue <: Queue
    retire_cnt::Int
    retire_total_duration::Time
    SinkQueue() = new(zero(Int), zero(Time))
end


function Base.push!(q::SinkQueue, token, when)
    q.retire_cnt += 1
    q.retire_total_duration += when - token.created
end


throughput(q::SinkQueue) = q.retire_cnt / q.retire_total_duration
