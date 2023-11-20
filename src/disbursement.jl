export RoundRobin, RandomAssignment, ShortestQueueAssignment
export SizeIntervalAssignment, LeastWorkLeft

"""
Accepts tokens and chooses next one. These are _task assignment policies_.
"""

abstract type Assignment end
# Any, RoundRobin, Random, ByTokenType, ByTokenValue


mutable struct RoundRobin <: Assignment
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


struct RandomAssignment <: Assignment; end

function update_downstream!(r::RandomAssignment, downstream, when, rng)
    q_dest = queues(downstream)
    q_choose = rand(rng, q_dest)
    push!(downstream, q_choose, when)
    return q_choose
end


struct ShortestQueueAssignment <: Assignment; end

function update_downstream!(r::ShortestQueueAssignment, downstream, when, rng)
    q_dest = queues(downstream)
    smallest_queue_cnt = minimum(length(q) for q in q_dest)
    smallest_queue = [q for q in q_dest if length(q) == smallest_queue_cnt]
    q_choose = rand(rng, smallest_queue)
    push!(downstream, q_choose, when)
    return q_choose
end


"""
Size Interval Task Assignment (SITA) chooses a destination queue depending
on the role of that queue. This is typically a short, medium, long for jobs
in order to keep long jobs from clogging the queue.
"""
struct SizeIntervalAssignment <: Assignment
    token_to_symbol::Function
end


function update_downstream!(r::SizeIntervalAssignment, downstream, when, rng)
    token = finished_job(downstream)
    desired_role = r.token_to_symbol(token)
    q_dest = queues_with_role(downstream, desired_role)
    q_choose = rand(rng, q_dest)
    push!(downstream, q_choose, when)
    return q_choose
end


struct LeastWorkLeft <: Assignment; end

function update_downstream!(r::LeastWorkLeft, downstream, when, rng)
    q_dest = queues(downstream)
    work = [total_work(q) for q in q_dest]
    smallest_work = minimum(work)
    smallest_queue = [q_dest[idx] for (idx, w) in enumerate(work) if w <= smallest_work]
    q_choose = rand(rng, smallest_queue)
    push!(downstream, q_choose, when)
    return q_choose
end
