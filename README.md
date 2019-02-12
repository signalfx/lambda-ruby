# SignalFx::Lambda

This gem provides a simplified way to get metrics and traces from AWS Lambda
functions written for the Ruby 2.5 runtime.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'signalfx-lambda'
```

And then execute:

    $ bundle install --path vendor/bundle

## Usage

Add this line to the top of your file:

```ruby
require 'signalfx/lambda'
```

To use the wrapper, register `source.SignalFx::Lambda::Tracing.wrapped_handler`
in the console, where `source` is your Ruby source file. Then somewhere after
your handler function definition, the function can be registered to be
automatically traced:

```ruby
# this is the original handler
def handler(event:, context:)
    JSON.generate(body)
end

SignalFx::Lambda.register_handler(metrics: true, tracing: true, &method(:handler))
```

`register_handler` will accept any block.

If passing in a block parameter, it must be the last argument.

It also takes these optional arguments:
- `metrics`: Enable reporting of metrics. Default: `true`
- `tracing`: Enable tracing. Default: `true`

### Endpoint configuration

If metrics and traces should be reported to a common endpoint, as is the case
when using the Smart Gateway, a single variable can be used:

```
SIGNALFX_ENDPOINT_URL = <gateway_url>
```

If the component-specific URLs below are set, they will take precedence over
`SIGNALFX_ENDPOINT_URL` for those components.

### Tracer configuration

The tracer used by the function is configured through environment variables:

```
SIGNALFX_ACCESS_TOKEN
SIGNALFX_SERVICE_NAME
SIGNALFX_TRACING_URL
```

In production, `SIGNALFX_TRACING_URL` should be pointing to your [Smart Gateway](https://docs.signalfx.com/en/latest/apm/apm-deployment/smart-gateway.html).
When pointing to the Smart Gateway, an access token is not needed. When not
configured, the ingest URL defaults to `https://ingest.signalfx.com/v1/trace`,
which requires an access token to be configured.

The tracer will be persisted across invocations to the same context, reducing
the time needed for tracer initialization.

### SignalFx client configuration

The SignalFx client requires the following environment variables to be set:

```
SIGNALFX_ACCESS_TOKEN
SIGNALFX_METRICS_URL
```

When `SIGNALFX_METRICS_URL` is pointing to a Gateway in production, the access
token is not needed.

The metrics URL will default to `https://ingest.signalfx.com` when not configured.

## Trace and tags

The wrapper will generate a single span per function invocation. This span will
be named with the pattern  `lambda_ruby_<function_name>`. The span prefix can be
optionally configured with the `SIGNALFX_SPAN_PREFIX` environment variable:

    $ SIGNALFX_SPAN_PREFIX=custom_prefix_

This will make spans have the name `custom_prefix_<function_name>`

Each span will also have the following tags:
- `component`: `ruby-lambda-wrapper`
- `lambda_arn`: the full ARN of the invocation
- `aws_request_id`: the identifier of the invocation request
- `aws_region`: the region that the function executed in
- `aws_account_id`: id of the account this function ran for
- `aws_function_name`: the function name set for this Lambda
- `aws_function_version`: the function version
- `aws_execution_env`: the name of the runtime environment running this function
- `log_group_name`: log group for the function
- `log_stream_name`: log stream for the instance
- `function_wrapper_version`: the version of this wrapper gem being used

If a `qualifier` is present in the ARN, depending on the resource type, either `aws_function_qualifier` or `event_source_mappings` will be tagged.

## Metrics

When metrics are enabled, the following datapoints are sent to SignalFx:

| Metric Name            | Type    | Description                                                     |
| ---                    | ---     | ---                                                             |
| `function.invocations` | Counter | Count number of Lambda invocations                              |
| `function.cold_starts` | Counter | Count number of cold starts                                     |
| `function.errors`      | Counter | Count number of errors captured from underlying Lambda handler  |
| `function.duration`    | Gauge   | Execution time of the underlying Lambda handler in milliseconds |

Each datapoint has the following dimensions:
- `metric_source`: `ruby-lambda-wrapper`
- `lambda_arn`: the full ARN of the invocation
- `aws_region`: the region that the function executed in
- `aws_account_id`: id of the account this function ran for
- `aws_function_name`: the function name set for this Lambda
- `aws_function_version`: the function version
- `aws_function_qualifier`: function version qualifier, which will be a version
  or version alias if it is not an event source mapping invocation
- `event_source_mappings`: function name if it is an event source mapping invocation
- `aws_execution_env`: the name of the runtime environment running this function
- `function_wrapper_version`: the version of this wrapper gem being used
- `log_group_name`: log group for the function
- `log_stream_name`: log stream for the instance

## Manual Instrumentation

### Tracing

Manual tracing may be useful to get a better view into the function. The
OpenTracing global tracer makes the tracer used by the wrapper available
when more specific instrumentation is desired.

```ruby
require 'opentracing'

OpenTracing.global_tracer.start_active_span("span_name") do |scope|

    work_to_be_traced

end
```

These manually created spans will automatically be nested, with the span for the
Lambda handler as the parent.

For more examples of usage, please see [opentracing-ruby](https://github.com/opentracing/opentracing-ruby).

### Metrics

Your function can be manually instrumented to send additional metrics using the
already configured SignalFx client.

```ruby
SignalFx::Lambda::Metrics.client.send(counters: ..., gauges: ..., cumulative_counters: ...)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/signalfx/lambda-ruby.

## License

The gem is available as open source under the terms of the [Apache 2.0 License](https://opensource.org/licenses/Apache-2.0).
