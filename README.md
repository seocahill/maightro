# maightr-

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