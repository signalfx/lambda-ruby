require 'signalfx/lambda/tracing/extractors'

require 'opentracing'
require 'jaeger/client'

module SignalFx
  module Lambda
    module Tracing
      class Error < StandardError; end

      def self.wrap_function(event, context, &block)
        init_tracer if !@tracer # avoid initializing except on a cold start

        response = nil
        OpenTracing.start_active_span("#{@span_prefix}#{context.function_name}", tags: build_tags(context)) do |scope|
          response = yield event: event, context:context

          scope.span.set_tag("http.status_code", response[:statusCode]) if response[:statusCode]
        end

        # flush the spans before leaving the execution context
        @reporter.flush
        response
      end

      def self.wrapped_handler(event:, context:)
        wrap_function(event, context, &@handler)
      end

      def self.build_tags(context)
        tags = {
          'component' => 'ruby-lambda-wrapper',
          'lambda_arn' => context.invoked_function_arn,
          'aws_request_id' => context.aws_request_id,
          'aws_function_name' => context.function_name,
          'aws_function_version' => context.function_version,
          'aws_execution_env' => ENV['AWS_EXECUTION_ENV'],
          'log_group_name' => context.log_group_name,
          'log_stream_name' => context.log_stream_name,
          'function_wrapper_version' => "signalfx-lambda-#{SignalFx::Lambda::VERSION}",
        }

        tags = tags.merge(tags_from_arn(context.invoked_function_arn))
      end

      def self.tags_from_arn(arn)
        _, _, _, region, account_id, resource_type, _, qualifier = arn.split(':')

        tags = {
          'aws_region' => region,
          'aws_account_id' => account_id,
        }

        if qualifier
          case resource_type
          when 'function'
            tags['aws_function_qualifier'] = qualifier
          when 'event-source-mappings'
            tags['event_source_mappings'] = qualifier
          end
        end

        tags
      end

      def self.register_handler(&handler)
        @handler = handler
      end

      def self.init_tracer
        access_token = ENV['SIGNALFX_ACCESS_TOKEN']
        ingest_url = ENV['SIGNALFX_INGEST_URL'] || 'https://ingest.signalfx.com/v1/trace'
        service_name = ENV['SIGNALFX_SERVICE_NAME'] || 'signalfx_lambda_tracing'
        @span_prefix = ENV['SIGNALFX_SPAN_PREFIX'] || 'lambda_ruby_'

        # configure the trace reporter
        headers = { }
        headers['X-SF-Token'] = access_token if !access_token.empty?
        encoder = Jaeger::Client::Encoders::ThriftEncoder.new(service_name: service_name)
        sender = Jaeger::Client::HttpSender.new(url: ingest_url, headers: headers, encoder: encoder, logger: Logger.new(STDOUT))
        @reporter = Jaeger::Client::Reporters::RemoteReporter.new(sender: sender, flush_interval: 1)

        # propagation format configuration
        injectors = {
          OpenTracing::FORMAT_TEXT_MAP => [Jaeger::Client::Injectors::B3RackCodec]
        }
        extractors = {
          OpenTracing::FORMAT_TEXT_MAP => [SignalFx::Lambda::Tracing::B3TextMapCodec]
        }

        OpenTracing.global_tracer = Jaeger::Client.build(
          service_name: service_name,
          reporter: @reporter,
          injectors: injectors,
          extractors: extractors
        )

        @tracer = OpenTracing.global_tracer
      end
    end
  end
end
