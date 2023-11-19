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
    modify!(s_event, event_token)
    model.server_available[s_event_id] = true

    # That event_token will go to one of the queues waiting for it.
    q_receive_ids = outqueues(model.network, s_event_id)
    # All this setup making temporary dictionaries is meant to allow users'
    # code to focus on outgoing queues and their roles.
    q_receive_dict = Dict{Symbol,Queue}()
    role_to_id = Dict{Symbol,Int}()
    for q_id in q_receive_ids
        role = model.queue_role[(s_event_id, q_id)]
        q_receive_dict[role] = model.queue[q_id]
        role_to_id[role] = q_id
    end
    q_dest_sym = destination!(s_event, q_receive_dict, event_token)
    q_dest_id = role_to_id[q_dest_sym]
    q_dest = model.queue[q_dest_id]
    push!(q_dest, event_token)

    # Changing the receiving queue could start waiting servers.
    server_ids = outservers(model.network, q_dest_id)
    push!(server_ids, s_event_id)  # The original server could start again.

    for s_ready_id in server_ids
        if model.server_available[s_ready_id]
            # There is exactly one input queue for each server.
            q_only_id = inqueues(model.network, s_ready_id)[1]
            s_ready_role = model.server_role[(q_only_id, s_ready_id)]
            s_ready = model.server[s_ready_id]
            take_token = get_token!(model.queue[q_only_id], s_ready, s_ready_role)
            if take_token !== nothing
                fire_rate = rate(model.server[s_ready_id], take_token)
                start!(trajectory, s_ready_id, fire_rate)
                model.server_tokens[s_ready_id] = take_token
                model.server_available[s_ready_id] = false
            end
        end
    end
end
