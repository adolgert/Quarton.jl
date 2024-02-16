# Definition of a Queueing Model

This is an overview of the kinds of queueing models this Julia package can support.

## Goals

 * Compose a queueing model with other models. For instance, the token of a Petri net might become a job in the queueing model. Or a Markov model state could produce a job.

## Defining a Set of Random Variables

A queueing model is a set of random variables:

 - Servers - ``\{S_i\}``, a set of servers indexed by ``i``. A server consists of two parts,
   - A time for completion of service of the current job, ``T_i``. The cumulative density function of this random variable is ``F_i(t)``, which can be exponentially-distributed (M) or generally-distributed (G).
   - Any other internal state.
 - Queues - ``\{Q_j\}``, a set of queues indexed by ``j``. A queue consists off two parts,
   - A counting process of the current number of jobs in the queue, ``N_j``
   - Any other internal state.
 - ServerAssignment - When a server is idle, the queue that feeds it jobs may or may not move a job to the server.
 - QueueAssignment - When a server completes a job, this is the random variable that represents the queue to which the job will go and how that job is changed.

Jobs move through the system. The state of a job is

 - its current server or queue location
 - any internal state

When a job leaves a queue, it must go to a server. When a job leaves a server, it must go to a queue. This is represented by a directed graph which we call bipartite because there are no edges from server to server or from queue to queue. Every server has exactly one input queue. A queue may have zero or more output servers.

The servers and queues are joint random variables on a ``\sigma``-algebra defined by the set of events ``E_n`` which are the servers completing a job. An event consists of

 - One server completes a job at time ``T_i``.
 - The input queue to that server may decrement its number of jobs, ``N_j``, or it may not. This is a random variable that can depend on _any_ state of the system. The value of this random variable is either the identity of the job that is removed from the queue or no job. That is, the job state may be changed when it arrives at the server.
 - The output queues from the server ``i`` may increment with the completed job. Which ones increment is a random variable that can depend on _any_ state of the system. The job state may be changed when it leaves the server. The single job may become multiple jobs in different queues or the same queue.
 - The servers which depend upon those output queues may begin to serve the new job, or they may interrupt their current job to serve the new job.

No other servers or queues in the system will change, so every event is local to a server, its input queue, its output queues, and their output servers. Whether jobs arrive at a server and where completed jobs go are both called assigment rules, but they are different kinds of random variables.

## Implications

Standard queueing models talk about infinite sources with exponential arrival times. For the model above, we'd interpret that as an infinite queue that leads to a server with an exponential serving time. It's equivalent. The same goes for sinks in a model. They can be queues with no servers pulling jobs from them.

What is the minimal set of information to recreate a trajectory?

 1. Server firing times.
 2. Any random draws by ServerAssignments.
 3. Any random draws by QueueAssignments.

There is a lot that happens when a server completes a job. You can think of it as an old state becoming a new state. Here we have input queue ``j``, the server ``i`` that completes a job, its output queues ``k``, and all the output servers of those queues, ``l``.

```math
(Q_j, S_i, \{Q_k\}, \{S_l\}) \rightarrow (Q'_j, S'_i, \{Q'_k\}, \{S'_l\})
```

In practice, we can break an event down into a set of sub-event steps.

 1. Choose a destination queue for the completed job (or destination queues for the completed jobs), make any modifications to the job, and put it in the destination queue.
 2. Given the new job, the destination queue examines its destination servers to see if it should start a new job, interrupt a job, or do nothing.
 3. The source queue of the original server decides whether to start a job on that server.

The danger of separating these steps is that we might exclude a useful model. For instance, is it possible that the server will select a job based on where its output job went? I think not, but the sequence above forbids this behavior, and the organization of the code reflects the sequence above.

The assignment rules have to carry state, for some versions of those rules. Do we consider that part of the queue and part of the server?


## A Functional Version

**Job arrives in queue** - Input is state of any of the system, including the queue and dependent servers. Output is a new state for the queue and all servers that queue servers.

**Newly idle server** - Input is a state of the system, including the queue for that server, the server, and other servers dependent on the same queue. Output is the queue and the single server that was newly idle, not the other servers.

**Job completed** - Input is state of the system, including the job, the server, and dependent queues. Output is a new server state, job state, and dependent queue states.


## Separate Model and State

You might want to keep the model and the state together in order to think about this the same way you'd envision an object-oriented system. Each of the events and its sub-events looks like a message in an object-oriented system. I have, in the past, separated the statistical model from the state of any trajectory of that system for a few different reasons. One is to conserve memory when multi-threading the sampling of trajectories. In this case, each trajectory can share the same base model. Another is that a model can be used for purposes other than sampling its trajectories. You could, for instance, evaluate the likelihood of a trajectory. You could evaluate the sensitivity of a trajectory. You could evaluate a goal function of a trajectory. What would it do to this model to separate the model and state, in Julia?

Every struct that is part of the model would be immutable. That's a start. The initializer of a system would produce a new state from the model. This is a `build()` step. The random variables in a model could, if we chose, use accessor functions to read their state. That would let us store the state in a vectorized way, so that the random variables use a featherweight pattern.


## Observers

I expect most of the computation not to be the time to sample a trajectory but the time to observe a trajectory and store information about it. This is the most complicated portion. When I read books on queueing theory, they estimate dozens of summary variables about single servers and queues, or sets of servers and queues. They follow jobs through the system. It gets complicated. Successful packages address complexity head-on. How can we prepare to make observation of trajectories simple to specify, efficient to run, and simple to interpret.

Let's look at some examples.

 1. Response time is the total time a job spends in the system. That starts with the server firing to bring it into the system and ends with any server firing that removes if from the system. We could put a time marker in the job, but we don't need that memory used if this isn't a value that's needed.

 2. Service time - This is the time that servers serve a job during its time in the system. It's a subset of the response time. And you average it over all jobs.

 3. Average arrival rate - The rate at which jobs arrive into any one queue. We could measure this for every queue, but do we want to know it for all queues?

 4. The trajectory of the system is another observable.

In the same way the model and its state are separate, the observations are usually separate as well. How do we make a framework for specifying a model such that it can have hooks to observers for every sub-event?

 * One option is a database of observations on queues and on servers.
 * Another is a short summary of some kind, such as the average number of jobs in the system over time. This version forgets most of the events.

What's a good way to do this in Julia? Well, let's list some options.

 1. There is an observer struct, and each sub-event reports to that observer struct, passing the relevant server, queue, or job.
 2. We treat observation as an event log and use something like the Logging package, so it looks like messages into the aether.
 3. Every time there is a sample of an event, the model uses that sample to act on the state. We could record samples as a trajectory and all changes to state between samples as events. In other words, put something between the model and the state to record changes. I'm thinking about Haskell, where you lift operations into a different execution environment.

