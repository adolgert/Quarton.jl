# Quarton

Queueing models in continuous time. Build and run a queueing model.

This is research code in order to follow along with a book called _Performance Modeling and Design of Computer Systems: Queueing theory in action_ by Mor Harchol-Balter.

A queueing model has two types of parts.

 * A server accepts jobs from a queue and finishes those jobs at a rate specified by a probability distribution in time.
 * A queue accepts jobs from a server and holds them or disburses them to servers depending on rules.

In this code, you'll see jobs called tokens or work, and they are the same thing.

## Features

This code should support everything found in that book, so it's fairly generic.

 * Different types of queues: source, sink, FIFO.
 * Servers can draw times from Exponential distributions or any appropriate non-Exponential distribution.
 * Tokens can contain state.
 * Servers can modify tokens arbitrarily.
 * Tokens can be directed to queues depending on their values.
