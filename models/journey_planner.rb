#! /usr/bin/ruby
# frozen_string_literal: true

# Status quo
require 'uri'
require 'json'
require 'net/http'
# require 'pry'

require 'time'
require 'terminal-table'

class JourneyPlanner
  def search(date = '20221222', from = 'Ballina', to = 'Westport')
    @_search ||= Hash.new do |memo, (date, from, to)|
      memo[[date, from, to]] = _search(date, from, to)
    end

    @_search[[date, from, to]]
  end

  def _search(date, from, to)
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
                                         "name": from
                                         # "lid": 'A=1@O=Ballina@X=-9160592@Y=54109066@U=80@L=6000007@B=1@p=1669914383@'
                                       }
                                     ],
                                     "arrLocL": [
                                       {
                                         "name": to
                                         # "lid": 'A=1@O=Westport@X=-9510048@Y=53796206@U=80@L=6000085@B=1@p=1669914383@'
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
                                     "outDate": date,
                                     "outTime": '000000',
                                     "outPeriod": '1440',
                                     "retDate": date,
                                     "retTime": '000000',
                                     "retPeriod": '1440'
                                   },
                                   "id": '1|2|'
                                 }
                               ]
                             })

    response = https.request(request)
    stations = JSON.parse(response.body).dig('svcResL', 0, 'res', 'common', 'locL')
    trains_out = JSON.parse(response.body).dig('svcResL', 0, 'res', 'outConL')
    trains_ret = JSON.parse(response.body).dig('svcResL', 0, 'res', 'retConL')
    Struct.new(:stations, :trains_out, :trains_ret).new(stations, trains_out, trains_ret)
  end
end
