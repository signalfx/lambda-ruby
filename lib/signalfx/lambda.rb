require 'signalfx/lambda/version'
require 'signalfx/lambda/tracing'
require 'signalfx/lambda/metrics'

module SignalFx
  module Lambda
    class Error < StandardError; end

    COMPONENT = 'ruby-lambda-wrapper'.freeze

    class << self
      attr_accessor :fields

      def wrapped_handler(event:, context:)
        # gather some useful information from the execution context and ARN and
        # make it available to the handlers
        @fields = gather_fields(context)
        @wrapped_handler.call(event: event, context: context)
      end

      def register_handler(metrics: true, tracing: true, &handler)
        @handler = handler # the original handler

        # Add the wrappers needed
        wrappers = []
        wrappers.push(@handler)
        wrappers.push(Tracing.method(:wrap_function)) if tracing
        wrappers.push(Metrics.method(:wrap_function)) if metrics

        @wrapped_handler = build_wrapped_handler(wrappers) if @wrapped_handler.nil?
      end

      # build a nested block depending on the wrappers enabled
      def build_wrapped_handler(wrappers)
        wrappers.inject do |inner, outer|
          proc do |event:, context:|
            outer.call(event: event, context: context, &inner)
          end
        end
      end

      # build a map of useful properties from the context object
      def gather_fields(context)
        fields = {
          'lambda_arn' => context.invoked_function_arn,
          'aws_request_id' => context.aws_request_id,
          'aws_function_name' => context.function_name,
          'aws_function_version' => context.function_version,
          'aws_execution_env' => ENV['AWS_EXECUTION_ENV'],
          'log_group_name' => context.log_group_name,
          'log_stream_name' => context.log_stream_name,
          'function_wrapper_version' => "signalfx-lambda-#{SignalFx::Lambda::VERSION}",
        }

        fields.merge!(fields_from_arn(context.invoked_function_arn))
      end

      # the arn packs useful data, including region, account id, resource type,
      # and qualifier
      def fields_from_arn(arn)
        _, _, _, region, account_id, resource_type, _, qualifier = arn.split(':')

        fields = {
          'aws_region' => region,
          'aws_account_id' => account_id,
        }

        if qualifier
          case resource_type
          when 'function'
            fields['aws_function_qualifier'] = qualifier
          when 'event-source-mappings'
            fields['event_source_mappings'] = qualifier
          end
        end

        fields
      end
    end
  end
end
