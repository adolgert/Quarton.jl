export Work

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
