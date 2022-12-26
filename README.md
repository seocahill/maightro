# maightr-

## Using

- tailwind
- htmx https://htmx.org/
- sinatra
- simple datatables https://github.com/fiduswriter/Simple-DataTables

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