#! /usr/bin/ruby

=begin
Naive Algorithm:
- Westport is infallible!  Ballina train is supine, BT must be at MJ to meet WT.
- BMT duration is 27.  Minimum dwell is 3 minutes.
- For each WT at MJ
	- Check direction of train
	- Add  BT dep/arr times to hash table for appropriate dir of travel
	- Ignore scheduling clashes for now (e.g self or freight paths)
  - 2 blocks WM, BM.
=end

require "uri"
require "json"
require "net/http"
require "pry"

require "uri"
require "json"
require "net/http"
require "time"
require 'terminal-table'

url = URI("https://journeyplanner.irishrail.ie/bin/mgate.exe?rnd=1669936211572")

https = Net::HTTP.new(url.host, url.port)
https.use_ssl = true

request = Net::HTTP::Get.new(url)
request["Content-Type"] = "application/json"
request.body = JSON.dump({
  "id": "pv28umgwk8wbgk8g",
  "ver": "1.22",
  "lang": "eng",
  "auth": {
    "type": "AID",
    "aid": "320rteiJasdnj7H9"
  },
  "client": {
    "id": "IRISHRAIL",
    "type": "WEB",
    "name": "webapp",
    "l": "vs_webapp"
  },
  "formatted": false,
  "ext": "IR.1",
  "svcReqL": [
    {
      "meth": "TripSearch",
      "req": {
        "depLocL": [
          {
            "name": "Ballina",
            "lid": "A=1@O=Ballina@X=-9160592@Y=54109066@U=80@L=6000007@B=1@p=1669914383@"
          }
        ],
        "arrLocL": [
          {
            "name": "Westport",
            "lid": "A=1@O=Westport@X=-9510048@Y=53796206@U=80@L=6000085@B=1@p=1669914383@"
          }
        ],
        "minChgTime": -1,
        "liveSearch": false,
        "maxChg": 1000,
        "jnyFltrL": [
          {
            "type": "PROD",
            "mode": "INC",
            "value": 1023
          }
        ],
        "trfReq": {
          "tvlrProf": [
            {
              "type": "E"
            }
          ]
        },
        "getPolyline": true,
        "outFrwd": true,
        "getPasslist": true,
        "outDate": "20221222",
        "outTime": "000000",
        "outPeriod": "1440",
        "retDate": "20221222",
        "retTime": "000000",
        "retPeriod": "1440"
      },
      "id": "1|2|"
    }
  ]
})

response = https.request(request)
trains_out = JSON.parse(response.body).dig("svcResL", 0, "res", "outConL")
trains_ret = JSON.parse(response.body).dig("svcResL", 0, "res", "retConL")

timetable = []
TrainPath = Struct.new(:from, :dir, :dep, :arr, :station) do
  def arr_time
    return if arr.nil?
    Time.parse(arr[0..3].insert(2, ":"))
  end

  def dep_time
    return if dep.nil?
    Time.parse(dep[0..3].insert(2, ":"))
  end
end

trains_out.each do |train|
  train.dig('secL').each do |line|
    dir = nil
    stops = line.dig("jny", "stopL").map do |trip|
      dir ||= trip.dig("dDirTxt")
      arr = trip.dig("aTimeS")
      dep = trip.dig("dTimeS")
      loc = trip.dig("locX")
      from = "Ballina"
      TrainPath.new(nil, dir, dep, arr, loc)
    end
    timetable << stops
  end
end

trains_ret.each do |train|
  train.dig('secL').each do |line|
    dir = nil
    stops = line.dig("jny", "stopL").map do |trip|
      dir ||= trip.dig("dDirTxt")
      arr = trip.dig("aTimeS")
      dep = trip.dig("dTimeS")
      loc = trip.dig("locX")
      from = "Westport"
      TrainPath.new(nil, dir, dep, arr, loc)
    end
    timetable << stops
  end
end

manulla_times = timetable.flatten.select { |t| t.station == 1 }.reject { |t| t.dir == "Ballina" }.reject { |t| t.dir == "Manulla Junction" }
ballina_trains = []

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
bal_block = 27*60
wes_block = 19*60

binding.pry

first_ballina_train = timetable.flatten.select { |t| t.station == 3 }.sort_by { |t| t.arr || t.dep }.first
train_location = "Ballina"
dep_time = first_ballina_train.dep_time
full_trip = min_dwell + wes_block + (bal_block * 2)

start_time = Time.parse("05:00")
arr_time = nil

transfer = manulla_times.sort_by { |t| t.arr || t.dep }

start_pos = "Ballina"

# generate trains until latest arrival time
until arr_time > Time.parse("01:00")
  next_transfer = manulla_times.sort_by { |t| t.arr || t.dep }.slice
  # get next connect
  # if can do full trip make train, calc duration based on current position, dir of connecting train
  # else create train to meet connect and pop off queue
  # update start_time, arr_time and position
end

# FIFO
manulla_times.sort_by { |t| t.arr || t.dep }.each_cons(2).each do |ct, nt|
  transfer = ct.arr_time || ct.dep_time
  if ct.dir == "Dublin Heuston"
    bwt = TrainPath.new("Ballina-Westport",  "to #{ct.dir}",  (transfer - bal_block).strftime("%H:%M"), (transfer + wes_block).strftime("%H:%M"), nil)
    ballina_trains << bwt
    # check next train
    if nt.dir == "Westport"
      # check if going to Ballina before or not
      if (nt.arr_time - bwt.arr_time) > full_trip
        # go to ballina
        ballina_trains << TrainPath.new("Ballina-Westport",  "no transfer",  (ct.arr_time + min_dwell).strftime("%H:%M"), (ct.arr_time + min_dwell + bal_block).strftime("%H:%M"), nil)
      end
    end
  elsif ct.dir == "Westport"
    # ballina - manulla - ballina train

  end
end


## Results
rows = ballina_trains.sort_by { |t| t.dep }
[nil, *rows, nil].each_cons(3) do |(prev, cur, nxt)|
  next if prev.nil?
  padding = (Time.parse(cur.dep) - Time.parse(prev.arr)).fdiv(60).round
  cur.station = padding
end
headers = %w[path connection dep arr dwell]
puts Terminal::Table.new rows: rows, headings: headers, title: "An Maightró", style: { all_separators: true}
