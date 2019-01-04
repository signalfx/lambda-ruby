require "lambda/tracing/version"

require 'opentracing'
require 'jaeger/client'

module Lambda
  module Tracing
    class Error < StandardError; end

    def self.handler
      init_tracer

      puts OpenTracing.global_tracer
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
      reporter = Jaeger::Client::Reporters::RemoteReporter.new(sender: sender, flush_interval: 1)

      # propagation format configuration
      injectors = {
        OpenTracing::FORMAT_TEXT_MAP => [Jaeger::Client::Injectors::B3RackCodec]
      }
      extractors = {
        OpenTracing::FORMAT_TEXT_MAP => [Jaeger::Client::Extractors::B3TextMapCodec]
      }

      OpenTracing.global_tracer = Jaeger::Client.build(
        reporter: reporter,
        injectors: injectors,
        extractors: extractors
      )
    end
  end
end
