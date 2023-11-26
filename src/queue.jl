
using DataStructures

export Queue, InfiniteSourceQueue, FIFOQueue, SummarySink, RandomQueue, total_work
export FiniteFIFOQueue, throughput

abstract type Queue end
abstract type SourceQueue <: Queue end
abstract type SinkQueue <: Queue end

id!(q::Queue, id::Int) = (q.id = id; q)
id(q::Queue) = q.id


mutable struct FIFOQueue{T} <: Queue
    deque::Deque{Tuple{T,Time}}
    retire_cnt::Int
    retire_total_duration::Time
    id::Int
    FIFOQueue{T}() where {T<:Token} =
        new(Deque{Tuple{T,Time}}(), zero(Int), zero(Time), zero(Int))
end

Base.push!(q::FIFOQueue, token, when) = push!(q.deque, (token, when))
Base.length(q::FIFOQueue) = length(q.deque)
Base.iterate(q::FIFOQueue, s...) = iterate(q.deque, s...)

function update_downstream!(q::FIFOQueue, downstream, when, rng)
    s_available = available_servers(downstream)
    shuffle!(rng, s_available)
    for s in s_available
        if !isempty(q.deque)
            token, emplace_time = popfirst!(q.deque)
            q.retire_cnt += 1
            delay = when - emplace_time
            q.retire_total_duration += when - emplace_time
            add_delay!(token, delay)
            push!(downstream, s, token)
        end
    end
    nothing
end

total_work(q::FIFOQueue) = sum(workload(w) for (w, t) in q.deque; init=0.0)

throughput(q::FIFOQueue) = q.retire_cnt / q.retire_total_duration

mutable struct InfiniteSourceQueue{T} <: SourceQueue
    create_cnt::Int
    id::Int
    builder::Function
    InfiniteSourceQueue{T}(builder=(when, rng)->T(1.0, when)) where {T<:Token} =
            new(zero(Int), zero(Int), builder)
end

function update_downstream!(q::InfiniteSourceQueue, downstream, when, rng)
    for s in available_servers(downstream)
        q.create_cnt += 1
        token = q.builder(when, rng)
        @assert workload(token) > 0.0
        push!(downstream, s, token)
    end
    nothing
end
Base.length(q::InfiniteSourceQueue) = 0


mutable struct SummarySink{T} <: SinkQueue
    retire_cnt::Int
    retire_total_duration::Time
    retire_total_delay::Time
    id::Int
    SummarySink{T}() where {T<:Token} =
        new(zero(Int), zero(Time), zero(Time), zero(Int))
end


function Base.push!(q::SummarySink, token, when)
    q.retire_cnt += 1
    q.retire_total_duration += when - created(token)
    q.retire_total_delay += delay(token)
end

Base.length(q::SummarySink) = q.retire_cnt

throughput(q::SummarySink) = q.retire_cnt / q.retire_total_duration
retired(q::SummarySink) = q.retire_cnt
duration(q::SummarySink) = q.retire_total_duration
delay(q::SummarySink) = q.retire_total_delay

update_downstream!(q::SummarySink, downstream, when, rng) = nothing
total_work(q::SummarySink) = 0.0  # This will be a type problem. Need the token type.


mutable struct RandomQueue{T} <: Queue
    queue::Vector{Tuple{T,Time}}
    retire_cnt::Int
    retire_total_duration::Time
    id::Int
    RandomQueue{T}() where {T<:Token} =
        new(Vector{Tuple{T,Time}}(), zero(Int), zero(Time), zero(Int))
end

Base.push!(q::RandomQueue, token, when) = push!(q.queue, (token, when))
Base.length(q::RandomQueue) = length(q.queue)

function update_downstream!(q::RandomQueue, downstream, when, rng)
    s_available = available_servers(downstream)
    shuffle!(rng, s_available)
    for s in s_available
        if !isempty(q.queue)
            take_idx = rand(rng, 1:length(q.queue))
            token, emplace_time = q.queue[take_idx]
            deleteat!(q.queue, take_idx)
            q.retire_cnt += 1
            delay = when - emplace_time
            q.retire_total_duration += delay
            add_delay!(token, delay)
            push!(downstream, s, token)
        end
    end
    nothing
end

total_work(q::RandomQueue) = sum(workload(w) for (w, t) in q.queue)

throughput(q::RandomQueue) = q.retire_cnt / q.retire_total_duration


mutable struct FiniteFIFOQueue{T} <: Queue
    deque::Deque{Tuple{T,Time}}
    limit::Int
    retire_cnt::Int
    retire_total_duration::Time
    drop_cnt::Int
    id::Int
    FiniteFIFOQueue{T}(limit::Int) where {T<:Token} = new(
        Deque{Tuple{T,Time}}(), limit, zero(Int), zero(Time), zero(Int), zero(Int)
        )
end

function Base.push!(q::FiniteFIFOQueue, token, when)
    if length(q.deque) <= q.limit
        push!(q.deque, (token, when))
    else
        q.drop_cnt += 1
    end
end
Base.length(q::FiniteFIFOQueue) = length(q.deque)

function update_downstream!(q::FiniteFIFOQueue, downstream, when, rng)
    s_available = available_servers(downstream)
    shuffle!(rng, s_available)
    for s in s_available
        if !isempty(q.deque)
            token, emplace_time = popfirst!(q.deque)
            q.retire_cnt += 1
            delay = when - emplace_time
            q.retire_total_duration += delay
            add_delay!(token, delay)
            push!(downstream, s, token)
        end
    end
    nothing
end

total_work(q::FiniteFIFOQueue) = sum(workload(w) for (w, t) in q.deque)

throughput(q::FiniteFIFOQueue) = q.retire_cnt / q.retire_total_duration
