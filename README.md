# Lambda::Tracing

This gem provides a simplified way to trace AWS Lambda functions written for the
Ruby 2.5 runtime.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lambda-tracing'
```

And then execute:

    $ bundle install --path vendor/bundle

## Usage

Add this line to the top of your file:

```ruby
require 'lambda/tracing'
```

To use the wrapper, the original `handler` can be wrapped as a separate handler:

```ruby
def wrapping_handler(event:, context:)
    Lambda::Tracing.wrap_function(event, context) do
        handler(event: event, context: context)
    end
end
```

In the AWS console, setting the handler `source.wrapping_handler` will trace and pass on the call to
the original handler.

For a slightly more hands-off approach, register `source.Lambda::Tracing.wrapped_handler`
in the console. Then somewhere after your handler function definition, the
function can be registered to be automatically traced:

```ruby
Lambda::Tracing.register_handler(&method(:handler))
```

There are no differences in the traces produced by either method.

### Tracer configuration

The tracer used by the function is configured through environment variables:

```
SIGNALFX_ACCESS_TOKEN
SIGNALFX_INGEST_URL
SIGNALFX_SERVICE_NAME
```

The tracer will be persisted across invocations to the same context, reducing the time needed for tracer initialization.

## Trace and tags

The span will be named with the pattern  `lambda_ruby_<function_name>`.

Each span will also have the following tags:
- `component`: ruby-lambda-wrapper
- `lambda_arn`: the full ARN of the invocation
- `aws_function_name`: the function name set for this Lambda
- `aws_function_version`: the function version
- `aws_execution_env`: the name of the runtime environment running this function
- `function_wrapper_version`: the version of this wrapper gem being used

If a `qualifier` is present in the ARN, depending on the resource type, either `aws_function_qualifier` or `event_source_mappings` will be tagged.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/lambda-tracing.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
