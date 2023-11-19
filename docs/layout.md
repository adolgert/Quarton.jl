Disbursement selection happens on the way out of a server or queue, so we add roles to the outgoing connections. Any choice made during disbursement can depend on the token, the role, and the target of that role.
e
```
source = infinite_queue()
sink = take_queue()
aq = queue()
bq = queue()
s1 = server()
s2 = server()
s3 = server()
connect(source, s1)
connect(s1, aq, :only) # what is aq to s1
connect(aq, s2, :one) # what is s2 to aq.
connect(s2, sink)
```

```
source -> s1 -> aq -> s2 -> sink
s2 -> aq

action!(s2, token) = (token.value = 2)
function route!(s2, token, queue_dict)
    if token.value == 2
        return :out
    else
        return :again
    end
end

function route!(s2, token, queue_dict)
    _, role = minimum((length(v), k) for (k,v) in queue_dict)
    return role
end

```
