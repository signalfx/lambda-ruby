require 'set'
require 'signalfx'

module SignalFx
  module Lambda
    module Metrics
      @@ephemeral_dimensions = Set['aws_request_id', 'log_stream_name']

      class Error < StandardError; end

      class << self
        attr_accessor :client

        def wrap_function(event:, context:)
          cold_start = @client.nil?
          init_client unless @client
          counters = []
          gauges = []

          dimensions = populate_dimensions(context)

          # time execution of next block
          start_time = Time.now
          response = yield event: event, context: context
          end_time = Time.now

          duration = ((end_time - start_time) * 1000) # duration in ms
          end_time = end_time.strftime('%s%L')

          counters.push(
            {
              :metric => 'function.invocations',
              :value => 1,
              :timestamp => end_time,
              :dimensions => dimensions
            }
          )

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
          @client.send(gauges: gauges, counters: counters) if @client
        end

        def populate_dimensions(context)
          dimensions = SignalFx::Lambda.fields
                           .reject {|key, _| @@ephemeral_dimensions.include?(key)}
                           .map do |key, val|
            { :key => key, :value => val }
          end
          dimensions.push({ :key => 'metric_source', :value => SignalFx::Lambda::COMPONENT })
        end

        def init_client
          access_token = ENV['SIGNALFX_ACCESS_TOKEN']
          ingest_endpoint = ENV['SIGNALFX_METRICS_URL'] || ENV['SIGNALFX_ENDPOINT_URL'] || 'https://ingest.signalfx.com'
          timeout = [ENV['SIGNALFX_SEND_TIMEOUT'].to_i, 1].max

          @client = SignalFx.new access_token, ingest_endpoint: ingest_endpoint, timeout: timeout
        end
      end
    end
  end
end

