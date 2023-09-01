module io.ballerina.observe.trace.extension.zipkin {
    requires io.opentelemetry.exporter.zipkin;
    requires io.ballerina.runtime;
    requires io.opentelemetry.api;
    requires io.opentelemetry.api.metrics;
    requires io.opentelemetry.context;
    requires io.opentelemetry.sdk.trace;
    requires io.opentelemetry.sdk.common;
    requires io.opentelemetry.extension.trace.propagation;
    requires io.opentelemetry.semconv;

    provides io.ballerina.runtime.observability.tracer.spi.TracerProvider
            with io.ballerina.observe.trace.zipkin.ZipkinTracerProvider;
}
