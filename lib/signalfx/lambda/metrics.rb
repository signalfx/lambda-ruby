require 'signalfx'

module SignalFx
  module Lambda
    module Metrics
      class Error < StandardError; end

      def self.wrap_function(event:, context:)
        cold_start = @client.nil?

        init_client unless @client

        dimensions = populate_dimensions(context)

        # time execution of next block
        start_time = Time.now
        response = yield event: event, context: context
        end_time = Time.now

        duration = (end_time - start_time).strftime('%s%L') # duration in ms

        counters = [
          { 
            :metric => 'function.invocations',
            :value => 1,
            :timestamp => end_time,
            :dimensions => dimensions
          }
        ]

        counters.push(
          {
            :metric => 'function.cold_starts',
            :value => 1,
            :timestamp => end_time,
            :dimensions => dimensions
          }
        ) if cold_start

        gauges = [
          {
            :metric => 'function.duration',
            :value => duration,
            :timestamp => end_time,
            :dimensions => dimensions
          }
        ]

        response
      rescue => error
        error_counter = {
          :metric => 'function.errors',
          :value => 1,
          :timestamp => end_time,
          :dimensions => dimensions
        }

        counters.push(error_counter)

        raise
      ensure
        # send metrics before leaving this block
        @client.send(gauges: gauges, counter: counters)
      end

      def populate_dimensions(context)
        dimensions = []
        SignalFx::Lambda.fields.each do |key, val|
          dimensions.push({ :key => key, :value => value })
        end
      end

      def self.init_client
        access_token = ENV['SIGNALFX_ACCESS_TOKEN']
        ingest_url = ENV['SIGNALFX_INGEST_URL']

        @client = SignalFx.new access_token, ingest_endpoint: 'http://localhost:9922'
      end
    end
  end
end

