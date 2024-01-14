using Quarton
using Catlab

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

    # decoration on servers
    ServerType::AttrType
    server::Attr(V₁,ServerType)
    BoolType::AttrType
    server_available::Attr(V₁,BoolType)
    TokenType::AttrType
    server_tokens::Attr(V₁,TokenType)
    NameType::AttrType
    server_name::Attr(V₁,NameType)

    # decoration on queues
    QueueType::AttrType
    queue::Attr(V₂,QueueType)
    queue_name::Attr(V₂,NameType)
end

@acset_type QueueModelType(QueueModelSch, index=[:src₁,:tgt₁,:src₂,:tgt₁]) <: AbstractBipartiteGraph 

# look at the schema
# to_graphviz(QueueModelSch)
to_graphviz(QueueModelSch, graph_attrs=Dict(:dpi=>"90",:size=>"12",:ratio=>"expand"))

TokenType = Work

model = QueueModelType{Symbol,Server,Bool,Vector{TokenType},Symbol,Queue}()

add_part!(
    model, :V₁,
    server = ModifyServer(1.0),
    server_available = false,
    server_name = :s1
)

add_part!(
    model, :V₂,
    queue = InfiniteSourceQueue{TokenType}(),
    queue_name = :source
)

add_part!(
    model, :V₂,
    queue = SummarySink{TokenType}(),
    queue_name = :sink
)

add_part!(
    model, :E₂₁,
    src₂ = only(incident(model, :source, :queue_name)),
    tgt₁ = only(incident(model, :s1, :server_name)),
    server_role = :only
)

add_part!(
    model, :E₁₂,
    src₁ = only(incident(model, :s1, :server_name)),
    tgt₂ = only(incident(model, :sink, :queue_name)),
    queue_role = :only
)

to_graphviz(model, node_labels=(:server_name,:queue_name), edge_labels=(:queue_role,:server_role))

trajectory = Trajectory(2342334)
start_time = zero(Float64)

# activate!(model, trajectory, s1, T())

# for i in 1:100
#     when, which = next(trajectory)
#     @test isfinite(when)
#     step!(model, trajectory, (when, which))
# end

s_id = only(incident(model, :s1, :server_name))
token = TokenType()

model[s_id,:server_tokens] = [token]

Quarton.start!(trajectory, s_id, Quarton.rate(model[s_id,:server], token))

model[s_id,:server_available] = false

# the sim loop
when, which = next(trajectory)

# function step!(model::T, trajectory, (when, s_event_id)) where {T<:QueueModelType}
    s_event_id = which
    Quarton.stop!(trajectory, s_event_id, when)
    s_event = model[s_event_id, :server]

# end

# lots of dispatch and moving between methods in different files from here on out
# (4th line onward in the step! method)

# queues downstream of this server
q_dest = model[incident(model, s_event_id, :src₁), [:tgt₂,:queue]]

r = s_event.disbursement

# push!(downstream, q_dest[r.next], when)
event_token = only(model[s_event_id, :server_tokens])
s_event.modify_token(event_token)