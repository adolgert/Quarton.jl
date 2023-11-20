export Work

abstract type Token end

mutable struct Work <: Token
    created::Time
end

created(t::Token) = 0.0
created(t::Work) = t.created
create!(t::Work, when) = (t.created = when; nothing)