# Total Order Multicast Implementation

This repository contains an Erlang implementation of a **Total Order Multicast** system, designed to ensure that all messages sent to a group of nodes are delivered in the same order across all workers. The project demonstrates concepts of distributed systems, such as message synchronization, proposals, and consensus.

## Features
- **Basic Multicast:** A simple implementation where messages are sent directly to all nodes without guaranteeing a total order.
- **Total Order Multicast:** A robust implementation using the ISIS protocol to ensure synchronized delivery order across all nodes.
- **GUI for Workers:** Visual representation of the workers' state using colored windows.

## Project Structure
- `total.erl`: Implements the Total Order Multicast protocol.
- `basic.erl`: Implements the Basic Multicast protocol for comparison.
- `worker.erl`: Defines the behavior of workers in the system.
- `toty.erl`: Main module to initialize and run the system.
- `gui.erl`: Graphical interface to display workers' states.
- `seq.erl`: Utility functions for sequence number generation and comparison.

## Requirements
- **Erlang/OTP:** Ensure you have Erlang installed on your system. You can download it from [Erlang Solutions](https://www.erlang.org/downloads).

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/total-order-multicast.git
   cd total-order-multicast
2. Compile the modules:
   ```bash
   erlc total.erl basic.erl worker.erl toty.erl gui.erl seq.erl
## How to Run
```bash
   erl
   # Once erl terminal shows up
   toty:start(total, 500, 100). # Parameters basic/total, Sleep, Jitter 
   toty:stop(). # Stop running the program
