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

# to_graphviz(QueueModelSch)

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
    model, :E₁₂,
    src₁ = only(incident(model, :source, :queue_name)),
    tgt₁ = only(incident(model, :s1, :server_name)),
    queue_role = :only
)

add_part!(
    model, :E₂₁,
    src₂ = only(incident(model, :s1, :server_name)),
    tgt₂ = only(incident(model, :sink, :queue_name)),
    server_role = :only
)

to_graphviz(model, node_labels=(:server_name,:queue_name), edge_labels=(:queue_role,:server_role))