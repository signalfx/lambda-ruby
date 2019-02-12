require 'signalfx/lambda/tracing/extractors'

require 'opentracing'
require 'jaeger/client'

module SignalFx
  module Lambda
    module Tracing
      class Error < StandardError; end

      class << self
        attr_accessor :tracer, :reporter

        def wrap_function(event:, context:, &block)
          init_tracer(event) if !@tracer # avoid initializing except on a cold start

          tags = SignalFx::Lambda.fields
          tags['component'] = SignalFx::Lambda::COMPONENT

          scope = OpenTracing.start_active_span("#{@span_prefix}#{context.function_name}",
                                                tags: tags)

          response = yield event: event, context: context
          scope.span.set_tag("http.status_code", response[:statusCode]) if response[:statusCode]

          response
        rescue => error
          if scope
            scope.span.set_tag("error", true)
            scope.span.log_kv(key: "message", value: error.message)
          end

          # pass this error up
          raise
        ensure
          scope.close if scope

          # flush the spans before leaving the execution context
          @reporter.flush
        end

        def wrapped_handler(event:, context:)
          wrap_function(event, context, &@handler)
        end

        def register_handler(&handler)
          @handler = handler
        end

        def init_tracer(event)
          access_token = ENV['SIGNALFX_ACCESS_TOKEN']
          ingest_url = ENV['SIGNALFX_TRACING_URL'] || ENV['SIGNALFX_ENDPOINT_URL'] || 'https://ingest.signalfx.com/v1/trace'
          service_name = ENV['SIGNALFX_SERVICE_NAME'] || event.function_name
          @span_prefix = ENV['SIGNALFX_SPAN_PREFIX'] || 'lambda_ruby_'

          # configure the trace reporter
          headers = { }
          headers['X-SF-Token'] = access_token if !access_token.empty?
          encoder = Jaeger::Client::Encoders::ThriftEncoder.new(service_name: service_name)
          sender = Jaeger::Client::HttpSender.new(url: ingest_url, headers: headers, encoder: encoder, logger: Logger.new(STDOUT))
          @reporter = Jaeger::Client::Reporters::RemoteReporter.new(sender: sender, flush_interval: 100)

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
end
