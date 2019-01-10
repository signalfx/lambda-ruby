# SignalFx::Lambda

This gem provides a simplified way to trace AWS Lambda functions written for the
Ruby 2.5 runtime.

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

SignalFx::Lambda::Tracing.register_handler(&method(:handler))
```

`register_handler` will accept any block.

### Tracer configuration

The tracer used by the function is configured through environment variables:

```
SIGNALFX_ACCESS_TOKEN
SIGNALFX_INGEST_URL
SIGNALFX_SERVICE_NAME
```

In production, `SIGNALFX_INGEST_URL` should be pointing to your [Smart Gateway](https://docs.signalfx.com/en/latest/apm/apm-deployment/smart-gateway.html).
When pointing to the Smart Gateway, an access token is not needed. When not
configured, the ingest URL defaults to `https://ingest.signalfx.com/v1/trace`,
which requires an access token to be configured.

The tracer will be persisted across invocations to the same context, reducing
the time needed for tracer initialization.

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

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/signalfx/lambda-ruby.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
