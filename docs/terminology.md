# Terminology

These are terms from the book and are reflected in the code. Definitions here quote that book.

 * Service Order - The order in which jobs will be served, usually first-come first-serve.

 * Average arrival rate - hazard rate for jobs to arrive to the server.

 * Mean interarrival time - Inverse of average arrival rate, or inverse hazard.

 * Service requirement, size - Workload of the job, a random variable S, where time is measured relative to the server speed.

 * Mean service time - E[S], expectation value.

 * Average service rate - Estimator for hazard, or $\mu=1/E[S]$.

 * Response time, soujourn time - duration of job in system.

 * Waiting time, or delay, $T_Q$, the time the job spends in the queue, not being served. Note $E[T]=E[T_Q]+E[S]$.

 * Number of jobs in the system $N$.

 * Number of jobs in the queue, $N_Q$.
