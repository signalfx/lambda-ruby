require 'signalfx'

module SignalFx
  module Lambda
    module Metrics
      class Error < StandardError; end

      def self.wrap_function(event:, context:)
        init_client unless @client

        start_time = Time.now

        response = yield event: event, context: context

        end_time = Time.now
        duration = (end_time - start_time).strftime('%s%L') duration in ms

        dimensions = populate_dimensions(context)

        counters = [
          { 
            :metric => 'function.invocations',
            :value => '',
            :timestamp => end_time,
            :dimensions => dimensions
          },
          {
            :metric => 'function.cold_starts',
            :value => '',
            :timestamp => end_time,
            :dimensions => dimensions
          },
          {
            :metric => 'function.errors',
            :value => '',
            :timestamp => end_time,
            :dimensions => dimensions
          }
        ]

        gauges = [
          {
            :metric => 'function.duration',
            :value => '',
            :timestamp => end_time,
            :dimensions => dimensions
          }
        ]


        @client.send(gauges: gauges, counter: counters)
      rescue => error
        puts "error #{error}"
      end

      def populate_dimensions(context)
        _, _, _, region, account_id, resource_type, _, qualifier = arn.split(':')

        dimensions = [
          { :key => 'lambda_arn', :value => context.invoked_function_arn },
          { :key => 'aws_region', :value => region },
          { :key => 'aws_account_id', :value => account_id },
          { :key => 'aws_function_name', :value => context.function_name },
          { :key => 'aws_function_version', :value => context.function_version },
          { :key => 'aws_execution_env', :value => ENV['AWS_EXECUTION_ENV'] },
          { :key => 'function_wrapper_version', :value => "signalfx-lambda-#{::SignalFx::Lambda::VERSION}" },
          { :key => 'metric_source', :value => 'ruby-lambda-wrapper'},
        ]

        if qualifier
          case resource_type
          when 'function'
            dimensions.add({ :key => 'aws_function_qualifier', :value => qualifier })
          when 'event_source_mappings'
            dimensions.add({ :key => 'event_source_mappings', :value => qualifier })
          end
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

