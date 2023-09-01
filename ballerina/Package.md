## Package Overview

The Zipkin Observability Extension is one of the tracing extensions of the<a target="_blank" href="https://ballerina.io/"> Ballerina</a> language.

It provides an implementation for tracing and publishing traces to a Zipkin Agent.

## Enabling Zipkin Extension

To package the Zipkin extension into the Jar, follow the following steps.
1. Add the following import to your program.
```ballerina
import ballerinax/zipkin as _;
```

2. Add the following to the `Ballerina.toml` when building your program.
```toml
[package]
org = "my_org"
name = "my_package"
version = "1.0.0"

[build-options]
observabilityIncluded=true
```

To enable the extension and publish traces to Zipkin, add the following to the `Config.toml` when running your program.
```toml
[ballerina.observe]
tracingEnabled=true
tracingProvider="zipkin"

[ballerinax.zipkin]
agentHostname="127.0.0.1"  # Optional Configuration. Default value is localhost
agentPort=9411             # Optional Configuration. Default value is 9411
```
