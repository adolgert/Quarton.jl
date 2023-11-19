export Work

abstract type Token end

struct Work <: Token
    created::Time
end

created(t::Token) = 0.0
created(t::Work) = t.created
