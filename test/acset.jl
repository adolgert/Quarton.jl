using GATlab, Catlab.Theories
using Catlab.CategoricalAlgebra
using Catlab.Graphs
using Catlab.Graphics

# function construct()
#     g = QueueGraph()
#     server_cnt = 3
#     queue_cnt = 3
#     for sidx in 1:server_cnt
#         add_part!(g, :S)
#     end
#     for qidx in 1:queue_cnt
#         add_part!(g, :Q)
#     end
#     return g
# end
# g = QueueGraph()

# construct()

# let the stuff we make inherit from this

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
# src₁,tgt₁ are for edges from servers to queues, v.v. for subscript 2
@present QueueModelSch <: SchBipartiteGraph begin
    # decoration on edges
    RoleType::AttrType
    queue_role::Attr(E₁₂,RoleType) # what a server means to a queue
    server_role::Attr(E₂₁,RoleType) # what a queue means to a server

    JobContainerType::AttrType
    server_jobs::Attr(V₁,JobContainerType)
    queue_jobs::Attr(V₂,JobContainerType)

    # decoration on servers
    ServerType::AttrType
    server::Attr(V₁,ServerType)

    # decoration on queues
    QueueType::AttrType
    queue::Attr(V₂,QueueType)
end


@present MarkedQueueModelSch <: QueueModelSch begin
    (Job,V₁V₂)::Ob
    V₁_inclusion::Hom(V₁,V₁V₂)
    V₂_inclusion::Hom(V₂,V₁V₂)
    job_loc::Hom(Job,V₁V₂)
end


@acset_type QueueModelType(QueueModelSch, index=[:src₁,:tgt₁,:src₂,:tgt₁]) <: AbstractBipartiteGraph

# Schema - Knows how to make a model.
# Julia datatype - build from the schema.
# Acset is an element of the Julia datatype. aka, a particular model
# State of the model.
# Observer of the model.
# Trajectory of the model.
struct Job end

struct Server end

function assign(c::Server, roles::AbstractVector)
    return roles[1]
end

struct Queue end

function assign(c::Queue, roles::AbstractVector)
    return roles[1]
end


queue_model = QueueModelType{Symbol,Vector{Job},Server,Queue}()

s1 = add_part!(
    queue_model, :V₁,
    server_jobs = Vector{Job}(),
    server = Server()
)

q1 = add_part!(
    queue_model, :V₂,
    queue_jobs = Vector{Job}(),
    queue = Queue()
)

add_part!(
    queue_model, :E₂₁,
    src₂ = q1,
    tgt₁ = s1,
    server_role = :only
)

# Start at s1. Compute preimage of tgt1, then from there walk back to src2.
queue_model[incident(queue_model, s1, :tgt₁), :src₂]

function get_queues_attached_to_server(model, s)
    model[incident(model, s, :tgt₁), :src₂]
end

function get_servers_attached_to_queue(model, q)
    model[incident(model, q, :tgt₂), :src₁]
end

add_parts!(
    queue_model, :V₂, 2,
    queue_jobs = fill(Vector{Job}(),2),
    queue = fill(Queue(),2)
)

add_parts!(
    queue_model, :E₁₂, 2,
    src₁ = [s1,s1],
    tgt₂ = [2,3],
    queue_role = [:something,:something]
)