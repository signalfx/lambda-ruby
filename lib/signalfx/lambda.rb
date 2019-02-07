require 'signalfx/lambda/version'
require 'signalfx/lambda/tracing'
require 'signalfx/lambda/metrics'

module SignalFx
  module Lambda
    class Error < StandardError; end

    def self.wrapped_handler(event:, context:)

      # todo

    end
  end
end
