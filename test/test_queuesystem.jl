using SafeTestsets

@safetestset "Model With Paltry Types" begin
    using Catlab
    using Quarton
    # Schema - Knows how to make a model.
    # Julia datatype - build from the schema.
    # Acset is an element of the Julia datatype. aka, a particular model
    # State of the model.
    # Observer of the model.
    # Trajectory of the model.
    struct PJob end

    struct PServer end

    function assign(c::PServer, roles::AbstractVector)
        return roles[1]
    end

    struct PQueue end

    function assign(c::PQueue, roles::AbstractVector)
        return roles[1]
    end

    queue_model = Quarton.QueueSystemType{Symbol,Vector{PJob},PServer,PQueue,Symbol}()

    s1 = add_part!(
        queue_model, :V₁,
        server_jobs = Vector{PJob}(),
        server = PServer()
    )
    @test s1 == 1

    q1 = add_part!(
        queue_model, :V₂,
        queue = PQueue()
    )
    @test q1 == 1

    @test 1 == add_part!(
        queue_model, :E₂₁,
        src₂ = q1,
        tgt₁ = s1,
        server_role = :only
    )

    # Start at s1. Compute preimage of tgt1, then from there walk back to src2.
    queue_model[incident(queue_model, s1, :tgt₁), :src₂]

    @test 2:3 == add_parts!(
        queue_model, :V₂, 2,
        queue = fill(PQueue(), 2)
    )

    @test 1:2 == add_parts!(
        queue_model, :E₁₂, 2,
        src₁ = [s1, s1],
        tgt₂ = [2, 3],
        queue_role = [:something, :something]
    )
end
