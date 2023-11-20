using DataStructures

export activate!, step!


function activate!(model::QueueModel, trajectory, server, token)
    s_id = findfirst(isequal(server), model.server)
    model.server_tokens[s_id] = token
    start!(trajectory, s_id, rate(server, token))
    model.server_available[s_id] = false
end


# Starting state is just before server produces token.
# Ending state is just after, when the token is where it goes
# and this server and/or another server may have started.
#
# Note on variable names:
#   An initial s is for server and q is for queue.
#   A final _id is the index into the model's values.
#   A final _role means it's the role tag.
function step!(model, trajectory, (when, s_event_id))
    # First take the token from the server that just completed work.
    stop!(trajectory, s_event_id, when)
    s_event = model.server[s_event_id]
    event_token = model.server_tokens[s_event_id]
    modify!(s_event, event_token, when)
    model.server_available[s_event_id] = true

    s_downstream = ServerDownstream(model, trajectory, s_event_id)
    q_dest = update_downstream!(s_event, s_downstream, when, trajectory.rng)

    # We care about two queues, the one that feeds the server that fired
    # and the one that just received a token. No others. Each of those
    # two gets to decide which available server can get a token.
    queue_ids = Set(inqueues(model.network, s_event_id))
    push!(queue_ids, id(q_dest))
    for q_update_id in queue_ids
        downstream = QueueDownstream(model, trajectory, q_update_id)
        update_downstream!(
            model.queue[q_update_id], downstream, when, trajectory.rng
            )
    end
end
