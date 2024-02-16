using SafeTestsets

@safetestset "Model With Paltry Types" begin
    using Random
    using Quarton
    using Catlab
    when = 0.0
    rng = Xoshiro(324243)

    T = Quarton.Work
    source_queue = Quarton.InfiniteSourceQueue{T}()
    server = Quarton.ArrivalServer(1.0)
    server_job_holder = Quarton.FIFOQueue{T}()

    queue_model = Quarton.QueueSystemType{Symbol,Quarton.FIFOQueue{T},Server,Queue,Symbol}()

    s1 = add_part!(
        queue_model, :V₁,
        server_jobs = server_job_holder,
        server = server
    )
    q1 = add_part!(
        queue_model, :V₂,
        queue = source_queue
    )
    e_q1_s1 = add_part!(
        queue_model, :E₂₁,
        src₂ = q1, tgt₁ = s1,
        server_role = :only
    )

    @test length(server_job_holder) == 0
    Quarton.update_downstream!(queue_model, q1, when, rng)
    @test length(server_job_holder) == 1
end
