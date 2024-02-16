using Catlab

export QueueSystemSch, QueueSystemType,
    get_queues_attached_to_server, get_servers_attached_to_queue

# @present SchBipartiteGraph(FreeSchema) begin
#   (V₁, V₂)::Ob
#   (E₁₂, E₂₁)::Ob
#   src₁::Hom(E₁₂, V₁)
#   tgt₂::Hom(E₁₂, V₂)
#   src₂::Hom(E₂₁, V₂)
#   tgt₁::Hom(E₂₁, V₁)
# end

# @abstract_acset_type AbstractBipartiteGraph <: HasBipartiteGraph
# Q (*) -- (1) S
# S (*) -- (*) Q
# Qs:
# 1. it seems there are both "Source" and "Sink" queues, does this mean this info ought to be
#    structurally encoded in the model? (i.e. a tripartite graph)

# our model is a "decorated bipartite graph"
# let V₁ be servers, V₂ be queues
# E₁₂ is edges from servers to queues
# E₂₁ is edges from queues to servers
# src₁,tgt₂ are the source (server) and target (queue) of an edge from servers to queues
# src₂,tgt₁ are the source (queue) and target (server) of an edge from queue from servers
@present QueueSystemSch <: SchBipartiteGraph begin
    # decoration on edges
    RoleType::AttrType
    queue_role::Attr(E₁₂,RoleType) # downstream role from server to a queue
    server_role::Attr(E₂₁,RoleType) # downstream role from a queue to a server

    JobContainerType::AttrType
    server_jobs::Attr(V₁,JobContainerType)

    # decoration on servers
    ServerType::AttrType
    server::Attr(V₁,ServerType)

    # decoration on queues
    QueueType::AttrType
    queue::Attr(V₂,QueueType)

    # names for servers and queues
    NameType::AttrType
    server_name::Attr(V₁,NameType)
    queue_name::Attr(V₂,NameType)
end

# @present MarkedQueueModelSch <: QueueModelSch begin
#     (Job,V₁V₂)::Ob
#     V₁_inclusion::Hom(V₁,V₁V₂)
#     V₂_inclusion::Hom(V₂,V₁V₂)
#     job_loc::Hom(Job,V₁V₂)
# end

@acset_type QueueSystemType(QueueSystemSch, index=[:src₁,:tgt₁,:src₂,:tgt₁]) <: AbstractBipartiteGraph

"""
    Grab the set of queues (part IDs) attached to a server.
"""
function get_queues_attached_to_server(model::T, s) where {T<:AbstractBipartiteGraph}
    model[incident(model, s, :src₁), :tgt₂]
end

"""
    Grab the set of servers (part IDs) attached to a queue.
"""
function get_servers_attached_to_queue(model::T, q) where {T<:AbstractBipartiteGraph}
    model[incident(model, q, :src₂), :tgt₁]
end