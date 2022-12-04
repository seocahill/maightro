#! /usr/bin/ruby
# frozen_string_literal: true

# Direct Algorithm:
# - Westport is infallible!  Ballina train is supine, BT must be at MJ to meet WT.
# - In this simulation no freight paths are included. Variables like staff, fuel etc are assumed to be sufficient.
# - BMT duration is 27.  Minimum dwell is 3 minutes. WMT duration is 19 mins.
# - Loop from start to end time creating local or connecting trains depending on path availability

require 'uri'
require 'json'
require 'net/http'
require 'pry'

require 'time'
require 'terminal-table'

url = URI('https://journeyplanner.irishrail.ie/bin/mgate.exe?rnd=1669936211572')

https = Net::HTTP.new(url.host, url.port)
https.use_ssl = true

request = Net::HTTP::Get.new(url)
request['Content-Type'] = 'application/json'
request.body = JSON.dump({
                           "id": 'pv28umgwk8wbgk8g',
                           "ver": '1.22',
                           "lang": 'eng',
                           "auth": {
                             "type": 'AID',
                             "aid": '320rteiJasdnj7H9'
                           },
                           "client": {
                             "id": 'IRISHRAIL',
                             "type": 'WEB',
                             "name": 'webapp',
                             "l": 'vs_webapp'
                           },
                           "formatted": false,
                           "ext": 'IR.1',
                           "svcReqL": [
                             {
                               "meth": 'TripSearch',
                               "req": {
                                 "depLocL": [
                                   {
                                     "name": 'Ballina',
                                     "lid": 'A=1@O=Ballina@X=-9160592@Y=54109066@U=80@L=6000007@B=1@p=1669914383@'
                                   }
                                 ],
                                 "arrLocL": [
                                   {
                                     "name": 'Westport',
                                     "lid": 'A=1@O=Westport@X=-9510048@Y=53796206@U=80@L=6000085@B=1@p=1669914383@'
                                   }
                                 ],
                                 "minChgTime": -1,
                                 "liveSearch": false,
                                 "maxChg": 1000,
                                 "jnyFltrL": [
                                   {
                                     "type": 'PROD',
                                     "mode": 'INC',
                                     "value": 1023
                                   }
                                 ],
                                 "trfReq": {
                                   "tvlrProf": [
                                     {
                                       "type": 'E'
                                     }
                                   ]
                                 },
                                 "getPolyline": true,
                                 "outFrwd": true,
                                 "getPasslist": true,
                                 "outDate": '20221222',
                                 "outTime": '000000',
                                 "outPeriod": '1440',
                                 "retDate": '20221222',
                                 "retTime": '000000',
                                 "retPeriod": '1440'
                               },
                               "id": '1|2|'
                             }
                           ]
                         })

response = https.request(request)
trains_out = JSON.parse(response.body).dig('svcResL', 0, 'res', 'outConL')
trains_ret = JSON.parse(response.body).dig('svcResL', 0, 'res', 'retConL')

timetable = []
TrainPath = Struct.new(:from, :dir, :dep, :arr, :position) do
  def arr_time
    return if arr.nil?

    Time.parse(arr[0..3].insert(2, ':'))
  end

  def dep_time
    return if dep.nil?

    Time.parse(dep[0..3].insert(2, ':'))
  end
end

trains_out.each do |train|
  train['secL'].each do |line|
    dir = nil
    stops = line.dig('jny', 'stopL').map do |trip|
      dir ||= trip['dDirTxt']
      arr = trip['aTimeS']
      dep = trip['dTimeS']
      loc = trip['locX']
      from = 'Ballina'
      TrainPath.new(nil, dir, dep, arr, loc)
    end
    timetable << stops
  end
end

trains_ret.each do |train|
  train['secL'].each do |line|
    dir = nil
    stops = line.dig('jny', 'stopL').map do |trip|
      dir ||= trip['dDirTxt']
      arr = trip['aTimeS']
      dep = trip['dTimeS']
      loc = trip['locX']
      from = 'Westport'
      TrainPath.new(nil, dir, dep, arr, loc)
    end
    timetable << stops
  end
end

manulla_times = timetable.flatten.select do |t|
  t.station == 1
end.reject { |t| t.dir == 'Ballina' }.reject { |t| t.dir == 'Manulla Junction' }

# option 1 start from middle
# start from Ballina, morning train. Finish in Ballina last connection to Westport.
# make sure each Dublin-Wesport train is connected to:
# for each connection, depending on direction, create a BW or WB train connecting WDW mainline train.
# Gaps if gap exists > 2 trips insert extra train e.g (27 + 19 + 3) * 2 = 98 mins.

# option two linear with decision at end of each block
# or starting from first train
# go up to meet westport
# continue to westport
# check which way next meetup is
# calculate if possible to make another roundtrip, if so do it
# if not wait and then travel up to make connection
# remember bal-fox and wes-cas can be useful trips in and of themselves also

# try 2 fallback to 1

min_dwell = 180
bal_block = 27 * 60
wes_block = 19 * 60

local_trains = []

first_ballina_train = timetable.flatten.select { |t| t.station == 3 }.min_by { |t| t.arr || t.dep }
train_location = 'Ballina'
dep_time = first_ballina_train.dep_time
full_trip = min_dwell + wes_block + (bal_block * 2)

dep_time = Time.parse('05:00')
arr_time = nil

transfer = manulla_times.sort_by { |t| t.arr || t.dep }

current_position = 'Ballina'

# generate local trains from initial departure time until latest arrival time
# connection train is Westport - Dublin, local train is Ballina - Westport
until arr_time > Time.parse('01:00')
  # get next connect
  next_transfer = manulla_times.min_by { |t| t.arr || t.dep }
  # if can do full local trip generate train and add to timetable.
  # a connection train can be from B to connect with W or D going to D or W, or from W to connect with D, going to B.
  # variables are: dir of connecting train, current position of Ballina train, time of connection, earliest time Ballina train can leave
  local_train = if full_train_trip_possible(connecting_train, current_position, dep_time)
                  add_local_train_to_timetable
                else
                  # create train to meet connect
                  # the destination of the local train is determined by the direction of the connecting train
                  add_connecting_train(connecting_train, current_position, dep_time)
                  # and pop off connecting trains queue
                  manulla_times.delete next_transfer
                end
  # new dep_time and position
  dep_time = local_train.arr_time + dwell
  current_position = local_train.position
  # add local_train to timetable
  local_trains << local_train
end

def add_local_train_to_timetable
  raise 'implement me'
end

def add_connecting_train(_connecting_train, _current_position, _dep_time)
  raise 'implement me'
end

# Print Timetable
rows = local_trains.sort_by(&:dep)
[nil, *rows, nil].each_cons(3) do |(prev, cur, _nxt)|
  next if prev.nil?

  padding = (Time.parse(cur.dep) - Time.parse(prev.arr)).fdiv(60).round
  cur.station = padding
end
headers = %w[path connection dep arr dwell]
puts Terminal::Table.new rows: rows, headings: headers, title: 'An Maightró', style: { all_separators: true }
