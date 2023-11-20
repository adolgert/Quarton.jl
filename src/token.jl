export Work, CountedWork

abstract type Token end

mutable struct Work <: Token
    load::Float64
    created::Time
    Work(load=1.0, when=0.0) = new(load, when)
end

workload(t::Work) = t.load

created(t::Token) = 0.0
created(t::Work) = t.created
create!(t::Work, when) = (t.created = when; nothing)

mutable struct CountedWork <: Token
    load::Float64
    mark::Int
    created::Time
    CountedWork(load=1.0, when=0.0) = new(load, one(Int), when)
end

workload(t::CountedWork) = t.load

created(t::CountedWork) = t.created
create!(t::CountedWork, when) = (t.created = when; nothing)
