require 'signalfx/lambda/version'
require 'signalfx/lambda/tracing'
require 'signalfx/lambda/metrics'

module SignalFx
  module Lambda
    class Error < StandardError; end

    attr_accessor :fields

    def self.nested_handler(event:, context:)
      # gather some useful information from the execution context and ARN and
      # make it available to the
      @fields = gather_fields(context)
      @wrapped_handler.call(event: event, context: context)
    end

    # def self.wrapped_handler(event:, context:)

    #   # build a set of useful info from the context object.
    #   # this will be useful for both metrics and tracing
    #   fields = gather_fields(context)

    #   response = nil
    #   span = nil

    #   # manually track the start time of the handler
    #   start_time = Time.now
    #   if @tracing
    #     response, span = Lambda.wrap_function(event: event, context: context, tags: fields, @handler)
    #   else
    #     response = @handler(event: event, context: context)
    #   end
    #   # if there is a span, grab the end time from that
    #   end_time = span.nil? ? Time.now || span.end_time

    #   duration = end_time - start_time

    #   Metrics.function_metrics(start_time: start_time, end_time: end_time, fields: fields)

    #   response
    # rescue Error => error

    #   raise
    # ensure
    #   # the final metrics and span sending should happen here
    #   Tracing.reporter.flush
    #   # Metrics.client.send
    # end

    def self.register_handler(&handler, metrics: true, tracing: true)
      @handler = handler # the original handler

      # Add the wrappers needed
      wrappers.add(Tracing.method(:wrap_function) if tracing
      wrappers.add(Metrics.method(:wrap_function) if metrics
      wrappers.add(@handler)

      @wrapped_handler = build_wrapped_handler(wrappers) if @wrapped_handler.nil?
    end

    # build a nested block depending on the wrappers enabled
    def self.build_wrapped_handler(wrappers)
      wrappers.inject do |inner, outer|
        proc do |event: event, context: context|
          outer.call(event: event, context: context, &inner)
        end
      end
    end

    # build a map of useful properties from the context object
    def self.gather_fields(context)
      fields = {
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

      field.merge!(fields_from_arn(context.invoked_function_arn))
    end

    # the arn packs useful data, including region, account id, resource type,
    # and qualifier
    def self.fields_from_arn(arn)
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
