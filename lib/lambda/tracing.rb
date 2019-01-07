require "lambda/tracing/version"

require 'opentracing'
require 'jaeger/client'

module Lambda
  module Tracing
    class Error < StandardError; end

    def self.wrapped_handler(event:, context:)
      init_tracer

      puts OpenTracing.global_tracer
      puts context.inspect

      tags = {
        'component' => 'ruby-lambda-wrapper',
        'lambda_arn' => context.invoked_function_arn,
        'aws_function_name' => context.function_name,
        'aws_function_version' => context.function_version,
        'aws_execution_env' => ENV['AWS_EXECUTION_ENV'],
        'function_wrapper_version' => "lambda-tracing-#{Lambda::Tracing::VERSION}",
      }

      tags = tags.merge(tags_from_arn(context.invoked_function_arn))

      response = nil
      @tracer.start_active_trace("lambda_ruby_#{context.function_name}", tags: tags) do |scope|
        response = @handler.call(event: event, context: context)
      end

      @reporter.flush
      response
    end

    def self.tags_from_arn(arn)
      _, _, _, region, account_id, resource_type, resource, qualifier

      tags = {
        'aws_region' => region,
        'aws_account_id' => account_id,
      }
      tags['aws_function_qualifier'] = qualifier if qualifier && resource_type == 'function'
      tags['event_function_qualifier'] = qualifier if qualifier && resource_type == 'event-source-mapping'

      tags
    end

    def self.register_handler(&handler)
      @handler = handler
    end

    def self.init_tracer
      access_token = ENV['SIGNALFX_ACCESS_TOKEN']
      ingest_url = ENV['SIGNALFX_INGEST_URL'] || 'https://ingest.signalfx.com/v1/trace'
      service_name = ENV['SIGNALFX_SERVICE_NAME'] || 'signalfx_lambda_tracing'

      # configure the trace reporter
      headers = { }
      headers['X-SF-Token'] = access_token if !access_token.empty
      encoder = Jaeger::Client::Encoders::ThriftEncoder.new(service_name: service_name)
      sender = Jaeger::Client::HttpSender.new(url: ingest_url, headers: headers, encoder: encoder, logger: Logger.new(STDOUT))
      @reporter = Jaeger::Client::Reporters::RemoteReporter.new(sender: sender, flush_interval: 1)

      # propagation format configuration
      injectors = {
        OpenTracing::FORMAT_TEXT_MAP => [Jaeger::Client::Injectors::B3RackCodec]
      }
      extractors = {
        OpenTracing::FORMAT_TEXT_MAP => [Jaeger::Client::Extractors::B3TextMapCodec]
      }

      OpenTracing.global_tracer = Jaeger::Client.build(
        reporter: @reporter,
        injectors: injectors,
        extractors: extractors
      )
    end
  end
end
