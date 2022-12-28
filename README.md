# maightr-

## Using

- tailwind
- htmx https://htmx.org/
- sinatra
- simple datatables https://github.com/fiduswriter/Simple-DataTables

### Todo
- all options should support to / from
- fix datatables bug
- filter just from column
- perhaps more info on each timetable (e.g connections)
- maybe price if available?

### Overview
enter date - generate timetable


Ballina
Foxford
Manulla
Castlebar
Westport


Maightro timetable, choose your flavour:

> Enter date

- existing Maightro light
- existing Maightro improved with good connections
- Ballina Maightro direct trains 'allowed' to travel to Westport
- Claremorris train added Maightro Max

> spits out timetables
> also stats

## Calculate free paths from Dub to West

- double track: calculate headway and create hash from dublin (full / empty)
- single track (port - west):
  - stations are meeting points create hash of stations and fill with train calling times
  - calculate free paths where any passenger train could cross another? e.g go through each station and meeting time and see if it's possible to schedule a train, if so add to paths.
  - also "find" secret crossings (e.g where trains meet outside stations)


## alternatively

- calculate full path of new train (all stations)
- query to see if any train are on the current block, if not advance, if so check if pass is realistic


```
Pdeudocode:

    Initialize an empty schedule for the trains.
    Initialize a queue of trains waiting to enter the track, with the trains at the beginning of the queue being the ones that arrived first.
    While the queue is not empty:
        Dequeue the first train from the queue.
        Find the first available block on the track that the train can enter, starting from the train's current station.
        If there is an available block, add the train to the schedule and mark the block as occupied by the train.
        If there is no available block, add the train back to the end of the queue.
    Return the completed schedule.

This algorithm ensures that trains are scheduled in the order in which they arrive at the stations, and that only one train is allowed on a block at a time. It also allows for any number of trains to be at the same station at the same time.

I hope this helps! Let me know if you have any questions or if you would like more information on implementing this algorithm.
```

```ruby
def schedule_trains(trains)
  # Initialize an empty schedule for the trains
  schedule = []

  # Initialize a queue of trains waiting to enter the track
  queue = trains

  while !queue.empty?
    # Dequeue the first train from the queue
    train = queue.shift

    # Find the first available block on the track that the train can enter, starting from the train's current station
    available_block = nil
    train.current_station.blocks.each do |block|
      if !block.occupied?
        available_block = block
        break
      end
    end

    # If there is an available block, add the train to the schedule and mark the block as occupied by the train
    if available_block
      schedule << train
      available_block.occupy(train)
    # If there is no available block, add the train back to the end of the queue
    else
      queue << train
    end
  end

  # Return the completed schedule
  schedule
end

```

Train scheduling is a complex problem that involves optimizing various objectives, such as minimizing travel time for passengers, maximizing the utilization of resources (e.g., trains, tracks, etc.), and minimizing operating costs. There are many algorithms and approaches that have been proposed to solve this problem, including mathematical programming, heuristics, and simulation-based approaches.

Some examples of algorithms and approaches that have been used to solve train scheduling problems include:

    Integer linear programming (ILP) models: These models formulate the train scheduling problem as a mathematical optimization problem, where the objective is to minimize a cost function (e.g., total travel time) subject to a set of constraints (e.g., track capacity, train availability, etc.). ILP models can provide optimal solutions, but they can be computationally expensive to solve for large-scale problems.

    Heuristic algorithms: These algorithms use heuristics (i.e., rules of thumb) to generate feasible solutions to the train scheduling problem. Heuristic algorithms are often faster than ILP models, but they may not always produce optimal solutions. Examples of heuristic algorithms for train scheduling include simulated annealing, tabu search, and genetic algorithms.

    Simulation-based approaches: These approaches use computer simulations to model the train scheduling problem and evaluate different scenarios. Simulation-based approaches can be used to optimize various objectives and take into account various constraints and uncertainties (e.g., delays, passenger demand, etc.).

There are many research papers and articles that have been published on the topic of train scheduling. Some examples of papers that describe the problem in detail and propose algorithms and approaches for solving it include:

    "A review of train scheduling models and algorithms" by X. Liu and K. G. Gebremedhin (Transportation Research Part B: Methodological, 2016)

    "A simulation-based train scheduling model for the Norwegian railway network" by J. E. Rødseth and B. O. Næss (Transportation Research Part C: Emerging Technologies, 2009)

    "A heuristic approach to the train scheduling problem" by J. M. Arroyo, J. M. Moreno-Pérez, and A. Muñoz (Transportation Research Part C: Emerging Technologies, 2003)

I hope this information is helpful! Let me know if you have any further questions or if you would like further guidance on finding additional resources on the topic of train scheduling.


 A greedy algorithm is an algorithmic paradigm that follows the problem-solving heuristic of making the locally optimal choice at each stage with the hope of finding a global optimum. The brute-force approach that we implemented does not follow this heuristic, as it simply checks all possible times without any regard for optimality.

 This algorithm uses a greedy approach by finding the closest connection time that is later than the current time at each iteration, and scheduling the train to arrive at that connection time if it falls within a certain range around it. If the current time is not within this range, the train is scheduled to depart at the current time. The algorithm then advances the current time by the total trip time and repeats the process until the current time exceeds the last arrival time.