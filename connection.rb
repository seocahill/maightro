#! /usr/bin/ruby
# frozen_string_literal: true

# Naive Algorithm:
# - Westport is infallible!  Ballina train is supine, BT must be at MJ to meet WT.
# - BMT duration is 27.  Minimum dwell is 3 minutes.
# - For each WT at MJ
#   - Check direction of train
#   - Add  BT dep/arr times to hash table for appropriate dir of travel
#   - Ignore scheduling clashes for now (e.g self or freight paths)
#   - 2 blocks WM, BM.

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
TrainPath = Struct.new(:from, :dir, :dep, :arr, :station)

trains_out.each do |train|
  train['secL'].each do |line|
    dir = nil
    stops = line.dig('jny', 'stopL').map do |trip|
      dir ||= trip['dDirTxt']
      arr = trip['aTimeS']
      dep = trip['dTimeS']
      loc = trip['locX']
      from = 'Ballina'
      TrainPath.new(from, dir, dep, arr, loc)
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
      TrainPath.new(from, dir, dep, arr, loc)
    end
    timetable << stops
  end
end

manulla_times = timetable.flatten.select do |t|
  t.station == 1
end.reject { |t| t.dir == 'Ballina' }.reject { |t| t.dir == 'Manulla Junction' }
ballina_trains = []

# TrainPath = Struct.new(:arr, :dep, :dir, :station, :from)

manulla_times.each do |wt|
  manulla = wt.arr || wt.dep
  transfer_time = manulla[0..3].insert(2, ':')

  from = Time.parse(transfer_time) - (27 * 60)
  ballina_trains << TrainPath.new('Ballina-Manulla', "to #{wt.dir}", from.strftime('%H:%M'), transfer_time, nil)

  depart_time = Time.parse(transfer_time) + 120
  to = depart_time + (27 * 60)
  connection = wt.dir == 'Westport' ? 'Dublin Heuston' : 'Westport'
  ballina_trains << TrainPath.new('Manulla-Ballina', "from #{connection}", depart_time.strftime('%H:%M'),
                                  to.strftime('%H:%M'), nil)
end

rows = ballina_trains.sort_by(&:dep)
[nil, *rows, nil].each_cons(3) do |(prev, cur, _nxt)|
  next if prev.nil?

  padding = (Time.parse(cur.dep) - Time.parse(prev.arr)).fdiv(60).round
  cur.station = padding
end
headers = %w[path connection dep arr dwell]
puts Terminal::Table.new rows: rows, headings: headers, title: 'An Maightró', style: { all_separators: true }

ba = ballina_trains.select { |t| t.from == 'Ballina-Manulla' }
bam = ba.each_cons(2).map do |a, b|
  Time.parse(b.dep) - Time.parse(a.dep)
end.then { |ts| ts.sum.fdiv(ts.length).fdiv(60).round }
bad = ba.map { |t| Time.parse(t.dep) - Time.parse(t.arr) }.then { |ts| ts.sum.fdiv(ts.length).fdiv(60).round }
wp = ballina_trains.reject { |t| t.from == 'Ballina-Manulla' }
wpm = wp.each_cons(2).map do |a, b|
  Time.parse(b.dep) - Time.parse(a.dep)
end.then { |ts| ts.sum.fdiv(ts.length).fdiv(60).round }
wpd = wp.map { |t| Time.parse(t.dep) - Time.parse(t.arr) }.then { |ts| ts.sum.fdiv(ts.length).fdiv(60).round }
free_paths = ballina_trains.select { |t| t.station.to_i > 30 }.count
short_turnarounds = ballina_trains.select { |t| t.station.to_i < 5 }.select { |t| t.from == 'Ballina-Manulla' }.count
puts '=' * 99
puts "#{ba.count} Trains each way, with an averge service gap of #{bam},  #{free_paths} free paths during service hours and #{short_turnarounds} quick turnarounds in Ballina."
puts '=' * 99
# Calculate Ballina <> Manulla trains
# Simple conclusion is that Dublin - Wesport arr at Manulla at  10:06  needs to be delayed by 30 mins.

# binding.pry
# puts response.read_body