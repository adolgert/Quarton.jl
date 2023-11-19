
# Both queues and servers need to be able to express logic about
# where tokens go next. I call it disbursement. In order to do that,
# they need to see their local environment. If we implemented the model
# with an object-oriented method, that might mean just giving them access
# to the list of downstream objects. Here, that state is held elsewhere
# more efficiently. So this file creates flyweights to give each server
# and queue access to make the choices it needs to make.

struct QueueDownstream
    model::QueueModel
    trajectory::Trajectory
    q_id::Int
end


function available_servers(d::QueueDownstream)
    return [
        d.model.server[idx] for idx in outservers(d.model.network, d.q_id)
        if d.model.server_available[idx]
    ]
end


function Base.push!(d::QueueDownstream, server, token)
    fire_rate = rate(server, token)
    s_id = id(server)
    start!(d.trajectory, s_id, fire_rate)
    d.model.server_tokens[s_id] = token
    d.model.server_available[s_id] = false
    modify_server_and_queue!(d.trajectory, s_id, d.q_id)
end


struct ServerDownstream
    model::QueueModel
    trajectory::Trajectory
    s_id::Int
end


function queues(d::ServerDownstream)
    [d.model.queue[idx] for idx in outqueues(d.model.network, d.s_id)]
end


# There is no token argument because it's always the one token.
function Base.push!(d::ServerDownstream, queue, when)
    push!(queue, d.model.server_tokens[d.s_id], when)
    modify_server_and_queue!(d.trajectory, d.s_id, id(queue))
end
