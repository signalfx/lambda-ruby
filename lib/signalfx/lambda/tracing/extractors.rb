# frozen_string_literal: true

# This is only needed until the next release of the jaeger client
module SignalFx 
  module Lambda 
    module Tracing
      class B3RackCodec
        class Keys
          TRACE_ID = 'HTTP_X_B3_TRACEID'.freeze
          SPAN_ID = 'HTTP_X_B3_SPANID'.freeze
          PARENT_SPAN_ID = 'HTTP_X_B3_PARENTSPANID'.freeze
          FLAGS = 'HTTP_X_B3_FLAGS'.freeze
          SAMPLED = 'HTTP_X_B3_SAMPLED'.freeze
        end.freeze

        def self.extract(carrier)
          B3CodecCommon.extract(carrier, Keys)
        end
      end

      class B3TextMapCodec
        class Keys
          TRACE_ID = 'x-b3-traceid'.freeze
          SPAN_ID = 'x-b3-spanid'.freeze
          PARENT_SPAN_ID = 'x-b3-parentspanid'.freeze
          FLAGS = 'x-b3-flags'.freeze
          SAMPLED = 'x-b3-sampled'.freeze
        end.freeze

        def self.extract(carrier)
          B3CodecCommon.extract(carrier, Keys)
        end
      end

      class B3CodecCommon
        def self.extract(carrier, keys)
          trace_id = TraceId.base16_hex_id_to_uint64(carrier[keys::TRACE_ID])
          span_id = TraceId.base16_hex_id_to_uint64(carrier[keys::SPAN_ID])
          parent_id = TraceId.base16_hex_id_to_uint64(carrier[keys::PARENT_SPAN_ID])
          flags = parse_flags(carrier[keys::FLAGS], carrier[keys::SAMPLED])

          return nil if span_id.nil? || trace_id.nil?
          return nil if span_id.zero? || trace_id.zero?

          SpanContext.new(
            trace_id: trace_id,
            parent_id: parent_id,
            span_id: span_id,
            flags: flags
          )
        end

        # if the flags header is '1' then the sampled header should not be present
        def self.parse_flags(flags_header, sampled_header)
          if flags_header == '1'
            Jaeger::SpanContext::Flags::DEBUG
          else
            TraceId.base16_hex_id_to_uint64(sampled_header)
          end
        end
        private_class_method :parse_flags
      end
    end
  end
end
