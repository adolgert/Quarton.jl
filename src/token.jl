export Work

abstract type Token end

struct Work <: Token
    created::Time
end
