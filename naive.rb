#! /usr/bin/ruby

=begin
Naive Algorithm:
- Westport is infallible!  Ballina trains is supine, BT must be at MJ to meet WT.
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
TrainPath = Struct.new(:arr, :dep, :dir, :station, :from)

trains_out.each do |train|
  train.dig('secL').each do |line|
    dir = nil
    stops = line.dig("jny", "stopL").map do |trip|
      dir ||= trip.slice("dDirTxt")
      arr = trip.slice("aTimeS")
      dep = trip.slice("dTimeS")
      loc = trip.slice("locX")
      from = "Ballina"
      TrainPath.new(arr, dep, dir, loc, from)
    end
    timetable << stops
  end
end

trains_ret.each do |train|
  train.dig('secL').each do |line|
    dir = nil
    stops = line.dig("jny", "stopL").map do |trip|
      dir ||= trip.slice("dDirTxt")
      arr = trip.slice("aTimeS")
      dep = trip.slice("dTimeS")
      loc = trip.slice("locX")
      from = "Westport"
      TrainPath.new(arr, dep, dir, loc, from)
    end
    timetable << stops
  end
end

# manulla_times =

binding.pry
# puts response.read_body