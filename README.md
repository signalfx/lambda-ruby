# SignalFx Ruby Lambda Wrapper

## Overview

You can use this document to add a SignalFx wrapper to your AWS Lambda for Ruby. 

The SignalFx Ruby Lambda Wrapper wraps around an AWS Lambda Ruby function handler, which allows metrics and traces to be sent to SignalFx.

At a high-level, to add a SignalFx Ruby Lambda wrapper, you can package the code yourself, or you can use a Lambda layer containing the wrapper and then attach the layer to a Lambda function.

To learn more about Lambda layers, please visit the AWS documentation site and see [AWS Lambda Layers](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html).

## Step 1: Add the Lambda wrapper in AWS
-----------------------------------------

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

2. Run the following command: 
```
    $ bundle install --path vendor/bundle
```

3. Package and deploy as usual. 

## Step 2: Locate and set the ingest endpoint

By default, this function wrapper will send data to the us0 realm. As a result, if you are not in the us0 realm and you want to use the ingest endpoint directly, then you must explicitly set your realm. 

To locate your realm:

1. Open SignalFx and in the top, right corner, click your profile icon.
2. Click **My Profile**.
3. Next to **Organizations**, review the listed realm.

To set your realm, when configuring variables, make sure to use a subdomain, such as ingest.us1.signalfx.com or ingest.eu0.signalfx.com. This action will take place in Step 3. 

## Step 3: Set environment variables

1. Set SIGNALFX_ACCESS_TOKEN with your correct access token. (If you are using Smart Gateway for both metrics and traces, then you can skip this step.) Review the following example. 
    ```bash
        SIGNALFX_ACCESS_TOKEN=access token
    ```
2. If you use POPS, Smart Gateway, or want to ingest directly from a realm other than us0, then you must set at least one endpoint variable. (For environment variables, SignalFx defaults to the us0 realm. As a result, if you are not in the us0 realm, you may need to set your environment variables.) There are two options: 

   * Option 1: You can update ``SIGNALFX_ENDPOINT_URL`` where both metrics and traces will be sent to the gateway address. Note that the path ``/v1/trace`` will be automatically added to the endpoint for traces. Review the following example. 
    ```bash
        SIGNALFX_ENDPOINT_URL=http://<my_gateway>:8080
    ```
   * Option 2: You can update ``SIGNALFX_ENDPOINT_URL`` to send traces to the gateway and ``SIGNALFX_METRICS_URL`` to send metrics through POPS. Review the following example.   
    
    ```bash
        SIGNALFX_METRICS_URL=https://ingest.signalfx.com
        SIGNALFX_ENDPOINT_URL=http://<my_gateway>:8080
    ```
    By default, `SIGNALFX_METRICS_URL` points to the `us0` realm. If you are not in this realm, you must use the correct subdomain (https://ingest.{REALM}.signalfx.com), as stated in Step 2. 
   
3. (Optional) Specify an operation timeout (in seconds) with the `SIGNALFX_SEND_TIMEOUT` environment variable. The default value is 1 second. Review the following example.
   ```bash
      SIGNALFX_SEND_TIMEOUT=1
    ```
3. (Optional) Set additional environment variables for tracer configuration. Review the following examples.  

    ```bash
        SIGNALFX_SERVICE_NAME
        SIGNALFX_TRACING_URL=tracing endpoint [ default: https://ingest.signalfx.com/v1/trace ]
    ```
For `SIGNALFX_TRACING_URL`: 
   * In production, `SIGNALFX_TRACING_URL` should point to your [Smart Gateway](https://docs.signalfx.com/en/latest/apm/apm-deployment/smart-gateway.html). In this situation, an access token is not needed.     
   * If `SIGNALFX_TRACING_URL` does not point to your Smart Gateway, then the tracing URL defaults to `https://ingest.signalfx.com/v1/trace`. In this situation, an access token is required.
   * By default, `SIGNALFX_TRACING_URL` points to the `us0` realm. If you are not in this realm, then you must use the correct subdomain (https://ingest.{REALM}.signalfx.com), as stated in Step 2. 
        
To learn more, see: 
  * [SignalFx Point of Presence Service (POPS)](https://docs.signalfx.com/en/latest/integrations/integrations-reference/integrations.signalfx.point.of.presence.service.(pops).html)
  * [Deploying the SignalFx Smart Gateway](https://docs.signalfx.com/en/latest/apm/apm-deployment/smart-gateway.html)        

## Step 4: Wrap a function

1. Add the following line to the top of your file: 

```ruby
require 'signalfx/lambda'
```

2. To use the wrapper, put `source.SignalFx::Lambda.wrapped_handler` as the handler
in the AWS console where `source` is your Ruby source file. 
   * When you use the AWS online code editor, `source` is `lambda_function`.  A complete handler value is
`lambda_function.SignalFx::Lambda.wrapped_handler`. 

3. In a space after your handler function definition, register the function to be automatically traced. Review the following example. 
```ruby
# this is the original handler
def handler(event:, context:)
    JSON.generate(body)
end

SignalFx::Lambda.register_handler(metrics: true, tracing: true, &method(:handler))
```

4. Consider the following statemeents regarding how to register the function. 
   * `register_handler` will accept any block.
   * If passing in a block parameter, then it must be the last argument.
   * You can also add these optional arguments:
      * `metrics`: Enable reporting of metrics. Default: `true`
      * `tracing`: Enable tracing. Default: `true`

## (Optional) Step 5: Send custom metrics from a Lambda function 

1. You can use the already-configured SignalFx client to send additional metrics from your function. Review the following example:

```ruby
SignalFx::Lambda::Metrics.client.send(counters: ..., gauges: ..., cumulative_counters: ...)
```

## (Optional) Step 6: Add manual tracing

You can add manual tracing to get a deeper view of the function. The OpenTracing global tracer makes the tracer used by the wrapper available when you want more specific instrumentation. Review the following example. 

```ruby
require 'opentracing'

OpenTracing.global_tracer.start_active_span("span_name") do |scope|

    work_to_be_traced

end
```

These manually created spans will automatically be nested, with the span for the Lambda handler as the parent. For more examples, please see [opentracing-ruby](https://github.com/opentracing/opentracing-ruby).

## Additional information

### Metrics and dimensions sent by the metrics wrapper

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

### Tags sent by the tracing wrapper

The wrapper will generate a trace per function invocation. The parent span will
be named with the pattern  `lambda_ruby_<function_name>`. The span prefix can be
optionally configured with the `SIGNALFX_SPAN_PREFIX` environment variable. Review the following example. 

    $ SIGNALFX_SPAN_PREFIX=custom_prefix_

This configuration will make spans have the name `custom_prefix_<function_name>`

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

### Development

After you check out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. 

To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version. Then, push git commits and tags, and then push the `.gem` file to [rubygems.org](https://rubygems.org).

### Contribution

You can send bug reports and pull requests through GitHub at https://github.com/signalfx/lambda-ruby.

### License
The gem is available as open source under the terms of the [Apache 2.0 License](https://opensource.org/licenses/Apache-2.0).
