
using DataStructures

export Queue, InfiniteQueue, FIFOQueue, SinkQueue

abstract type Queue end

id!(q::Queue, id::Int) = (q.id = id; q)
id(q::Queue) = q.id


mutable struct FIFOQueue <: Queue
    deque::Deque{Tuple{Token,Time}}
    retire_cnt::Int
    retire_total_duration::Time
    id::Int
    FIFOQueue() = new(Deque{Tuple{Token,Time}}(), zero(Int), zero(Time), zero(Int))
end

Base.push!(q::FIFOQueue, token, when) = push!(q.deque, (token, when))

function update_downstream!(q::FIFOQueue, downstream, when, rng)
    s_available = available_servers(downstream)
    shuffle!(rng, s_available)
    for s in s_available
        if !isempty(q.deque)
            token, emplace_time = popfirst!(q.deque)
            q.retire_cnt += 1
            q.retire_total_duration += when - emplace_time
            push!(downstream, s, token)
        end
    end
    nothing
end


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
    id::Int
    InfiniteQueue() = new(zero(Int), zero(Int))
end

function update_downstream!(q::InfiniteQueue, downstream, when, rng)
    for s in available_servers(downstream)
        q.create_cnt += 1
        push!(downstream, s, Work(when))
    end
    nothing
end

function get_token!(q::InfiniteQueue, server, server_role, when)
    q.create_cnt += 1
    Work(when)
end


mutable struct SinkQueue <: Queue
    retire_cnt::Int
    retire_total_duration::Time
    id::Int
    SinkQueue() = new(zero(Int), zero(Time), zero(Int))
end


function Base.push!(q::SinkQueue, token, when)
    q.retire_cnt += 1
    q.retire_total_duration += when - token.created
end


throughput(q::SinkQueue) = q.retire_cnt / q.retire_total_duration

update_downstream!(q::SinkQueue, downstream, when, rng) = nothing
