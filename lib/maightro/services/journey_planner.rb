# frozen_string_literal: true

require "uri"
require "json"
require "net/http"
require "time"

module Maightro
  module Services
    # Client for Irish Rail Journey Planner API.
    # Fetches real timetable data from Irish Rail.
    #
    # @example
    #   planner = JourneyPlanner.new
    #   results = planner.search("20231201", "Ballina", "Westport")
    #   results.trains_out.each { |trip| ... }
    #
    class JourneyPlanner
      SearchResult = Struct.new(:stations, :trains_out, :trains_ret, keyword_init: true)

      def initialize(vcr_bypass: false)
        @vcr_bypass = vcr_bypass.to_s
        @cache = {}
      end

      def search(date, from, to)
        cache_key = [date, from, to]
        return @cache[cache_key] if @cache.key?(cache_key)

        @cache[cache_key] = perform_search(date, from, to)
      end

      private

      def perform_search(date, from, to)
        url = URI("https://journeyplanner.irishrail.ie/bin/mgate.exe?rnd=1669936211572")

        https = Net::HTTP.new(url.host, url.port)
        https.use_ssl = true

        request = Net::HTTP::Get.new(url)
        request["Content-Type"] = "application/json"
        request["X-VCR-Bypass"] = @vcr_bypass
        request.body = build_request_body(date, from, to)

        response = https.request(request)
        parse_response(response.body)
      end

      def build_request_body(date, from, to)
        JSON.dump({
          id: "pv28umgwk8wbgk8g",
          ver: "1.22",
          lang: "eng",
          auth: {
            type: "AID",
            aid: "320rteiJasdnj7H9"
          },
          client: {
            id: "IRISHRAIL",
            type: "WEB",
            name: "webapp",
            l: "vs_webapp"
          },
          formatted: false,
          ext: "IR.1",
          svcReqL: [
            {
              meth: "TripSearch",
              req: {
                depLocL: [{ name: from }],
                arrLocL: [{ name: to }],
                minChgTime: -1,
                liveSearch: false,
                maxChg: 1000,
                jnyFltrL: [{ type: "PROD", mode: "INC", value: 1023 }],
                trfReq: { tvlrProf: [{ type: "E" }] },
                getPolyline: true,
                outFrwd: true,
                getPasslist: true,
                outDate: date,
                outTime: "000000",
                outPeriod: "1440",
                retDate: date,
                retTime: "000000",
                retPeriod: "1440"
              },
              id: "1|2|"
            }
          ]
        })
      end

      def parse_response(body)
        data = JSON.parse(body)

        SearchResult.new(
          stations: data.dig("svcResL", 0, "res", "common", "locL"),
          trains_out: data.dig("svcResL", 0, "res", "outConL"),
          trains_ret: data.dig("svcResL", 0, "res", "retConL")
        )
      end
    end

    # Parser for converting API response to train paths
    module TrainDataParser
      class << self
        def parse_train(train_data, trip, stations)
          from = find_station(train_data["dep"], stations)
          to = find_station(train_data["arr"], stations)
          dep = parse_time(train_data["dep"]["dTimeS"])
          arr = parse_time(train_data["arr"]["aTimeS"])
          stops = extract_stops(train_data, stations)
          dir = train_data.dig("jny", "dirTxt")

          TrainPathBuilder::SimplePath.new(
            from: from,
            to: to,
            dep: dep,
            arr: arr,
            stops: stops,
            trip_id: trip["cid"],
            dir: dir,
            info: "to #{dir}",
            position: to
          )
        end

        def parse_trip(trip, stations, from, to)
          routes = Domain::Route.connecting(from, to)

          trip["secL"].map do |train_data|
            train = parse_train(train_data, trip, stations)
            routes.each { |route| train.send("#{route.path_attribute}=", train.trip_id) }
            train
          end
        end

        private

        def find_station(loc_data, stations)
          index = loc_data["locX"]
          stations.dig(index, "name")
        end

        def parse_time(time_str)
          return nil unless time_str

          Time.parse(time_str[0..3].insert(2, ":"))
        end

        def extract_stops(train_data, stations)
          train_data.dig("jny", "stopL").map do |stop|
            name = find_station(stop, stations)
            time = parse_time(stop["dTimeS"]) || parse_time(stop["aTimeS"])
            [name, time]
          end
        end
      end
    end
  end
end
