# SignalFx Ruby Lambda Wrapper

## Overview

You can use this document to add a SignalFx wrapper to your AWS Lambda for Ruby. 

The SignalFx Ruby Lambda Wrapper wraps around an AWS Lambda Ruby function handler, which allows metrics and traces to be sent to SignalFx.

At a high-level, to add a SignalFx Ruby Lambda wrapper, you can package the code yourself, or you can use a Lambda layer containing the wrapper and then attach the layer to a Lambda function.

To learn more about Lambda Layers, please visit the AWS documentation site and see [AWS Lambda Layers](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html).

## Step 1: Add the Lambda wrapper in AWS

To add the SignalFx wrapper, you have the following options:
   
   * Option 1: In AWS, create a Lambda function, then attach a SignalFx-hosted layer with a wrapper.
      * If you are already using Lambda layers, then SignalFx recommends that you follow this option. 
      * In this option, you will use a Lambda layer created and hosted by SignalFx.
   * Option 2: In AWS, create a Lambda function, then create and attach a layer based on a SignalFx SAM (Serverless Application Model) template.
      * If you are already using Lambda layers, then SignalFx also recommends that you follow this option. 
      * In this option, you will choose a SignalFx template, and then deploy a copy of the layer.
   * Option 3: Use the wrapper as a regular dependency, and then create a Lambda function based on your artifact containing both code and dependencies.   

### Option 1: Create a Lambda function, then attach the SignalFx-hosted Lambda layer

In this option, you will use a Lambda layer created and hosted by SignalFx.

1. To verify compatibility, review the list of supported regions. See [Lambda Layer Versions](https://github.com/signalfx/lambda-layer-versions/blob/master/ruby/RUBY.md).
2. Open your AWS console. 
3. In the landing page, under **Compute**, click **Lambda**.
4. Click **Create function** to create a layer with SignalFx's capabilities.
5. Click **Author from scratch**.
6. In **Function name**, enter a descriptive name for the wrapper. 
7. In **Runtime**, select the desired language.
8. Click **Create function**. 
9. Click on **Layers**, then add a layer.
10. Mark **Provide a layer version**.
11. Enter an ARN number. 
   * To locate the ARN number, see [Lambda Layer Versions](https://github.com/signalfx/lambda-layer-versions/blob/master/ruby/RUBY.md).

### Option 2: Create a Lambda function, then create and attach a layer based on a SignalFx template

In this option, you will choose a SignalFx template, and then deploy a copy of the layer.

1. Open your AWS console. 
2. In the landing page, under **Compute**, click **Lambda**.
3. Click **Create function** to create a layer with SignalFx's capabilities.
4. Click **Browse serverless app repository**.
5. Click **Public applications**.
6. In the search field, enter and select **signalfx-lambda-ruby-wrapper**.
7. Review the template, permissions, licenses, and then click **Deploy**.
    * A copy of the layer will now be deployed into your account.
8. Return to the previous screen to add a layer to the function, select from list of runtime compatible layers, and then select the name of the copy. 

### Option 3: Install the wrapper package 

1. Add the following line to your application's Gemfile:

```ruby
gem 'signalfx-lambda'
```

2. Execute: 

```
$ bundle install --path vendor/bundle
```

## Step 2: Wrap a function 

The steps in this section can be performed in the AWS online code editor for your newly created Lambda function or in your application's Gemfile. As a result, these instructions are generic to apply to both user types. 

1. Add the following line to the top of your file: 

```ruby
require 'signalfx/lambda'
```

2. Set `source.SignalFx::Lambda.wrapped_handler` as the handler. 

Replace `source` with your Ruby source file. If you use the AWS online code editor, `lambda_function` is your `source`. 

A complete handler value is `lambda_function.SignalFx::Lambda.wrapped_handler`. 


3. In the AWS online code editor or in the Gemfile, after the handler function definition, register the function to be automatically traced:

```ruby
# this is the original handler
def handler(event:, context:)
    JSON.generate(body)
end

SignalFx::Lambda.register_handler(metrics: true, tracing: true, &method(:handler))
```

4. For your reference: 

`register_handler` will accept any block.

If passing in a block parameter, it must be the last argument.

It also takes these optional arguments:
- `metrics`: Enable reporting of metrics. Default: `true`
- `tracing`: Enable tracing. Default: `true`

### Endpoint configuration

If metrics and traces should be reported to a common endpoint, as is the case
when using the Smart Gateway, a single environment variable should be set:

```
SIGNALFX_ENDPOINT_URL=<gateway_url>
```

If the component-specific URLs below are set, they will take precedence over
`SIGNALFX_ENDPOINT_URL` for those components.

By default, the metrics and traces will be reported to the `us0` realm. If you are
not in this realm you will need to set the `SIGNALFX_TRACING_URL` and
`SIGNALFX_METRICS_URL` environment variables, as described below.

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

The default `SIGNALFX_TRACING_URL` points to the `us0` realm. If you are not in
this realm, you will need to set the environment variable to the correct realm
ingest endpoint (https://ingest.{REALM}.signalfx.com/v1/trace). To determine what realm
you are in, check your profile page in the SignalFx web application (click the
avatar in the upper right and click My Profile).

The tracer will be persisted across invocations to the same context, reducing
the time needed for tracer initialization.

### SignalFx client configuration

The SignalFx client requires the following environment variables to be set:

```
SIGNALFX_ACCESS_TOKEN
SIGNALFX_METRICS_URL
```

When `SIGNALFX_METRICS_URL` is pointing to a Smart Gateway in production, the
access token is not needed.

The metrics URL will default to `https://ingest.signalfx.com` when not configured.

The default `SIGNALFX_METRICS_URL` points to the `us0` realm. If you are not in
this realm, you will need to set the environment variable to the correct realm
ingest endpoint (https://ingest.{REALM}.signalfx.com). To determine what realm
you are in, check your profile page in the SignalFx web application (click the
avatar in the upper right and click My Profile).

Send operation timeout (in seconds) can be specified with `SIGNALFX_SEND_TIMEOUT`
environment variable. Default value is 1 second.
 
## Trace and tags

The wrapper will generate a trace per function invocation. The parent span will
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
