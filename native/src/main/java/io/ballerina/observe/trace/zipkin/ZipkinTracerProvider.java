/*
 * Copyright (c) 2023, WSO2 LLC. (https://www.wso2.com) All Rights Reserved.
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
package io.ballerina.observe.trace.zipkin;

import io.ballerina.observe.trace.zipkin.sampler.RateLimitingSampler;
import io.ballerina.runtime.api.values.BDecimal;
import io.ballerina.runtime.api.values.BString;
import io.ballerina.runtime.observability.tracer.spi.TracerProvider;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.context.propagation.ContextPropagators;
import io.opentelemetry.exporter.zipkin.ZipkinSpanExporter;
import io.opentelemetry.extension.trace.propagation.B3Propagator;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.SdkTracerProviderBuilder;
import io.opentelemetry.sdk.trace.export.BatchSpanProcessor;
import io.opentelemetry.sdk.trace.samplers.Sampler;

import java.io.PrintStream;
import java.util.Objects;
import java.util.concurrent.TimeUnit;

import static io.opentelemetry.semconv.ResourceAttributes.SERVICE_NAME;

/**
 * This is the Zipkin tracing extension class for {@link TracerProvider}.
 */
public class ZipkinTracerProvider implements TracerProvider {
    private static final String TRACER_NAME = "zipkin";
    private static final String APPLICATION_LAYER_PROTOCOL = "http";
    private static final PrintStream console = System.out;

    static SdkTracerProviderBuilder tracerProviderBuilder;

    @Override
    public String getName() {
        return TRACER_NAME;
    }

    @Override
    public void init() {    // Do Nothing
    }

    public static void initializeConfigurations(BString reporterEndpointUrl, BString agentHostname, int agentPort,
                                                BString samplerType, BDecimal samplerParam, int reporterFlushInterval,
                                                int reporterBufferSize) {

        String reporterEndpoint;
        if (!Objects.equals(String.valueOf(reporterEndpointUrl), "")) {
            reporterEndpoint = String.valueOf(reporterEndpointUrl);
            if (reporterEndpoint.contains("$TRACE_API_TOKEN")) {
                String token = System.getenv("TRACE_API_TOKEN");
                reporterEndpoint = reporterEndpoint.replaceAll("\\$TRACE_API_TOKEN", token);
            }
        } else {
            reporterEndpoint = APPLICATION_LAYER_PROTOCOL + "://" +
                    agentHostname + ":" + agentPort + "/api/v2/spans";
        }

        ZipkinSpanExporter exporter = ZipkinSpanExporter.builder().setEndpoint(reporterEndpoint).build();

        tracerProviderBuilder = SdkTracerProvider.builder()
                .addSpanProcessor(BatchSpanProcessor
                        .builder(exporter)
                        .setMaxExportBatchSize(reporterBufferSize)
                        .setExporterTimeout(reporterFlushInterval, TimeUnit.MILLISECONDS)
                        .build());

        tracerProviderBuilder.setSampler(selectSampler(samplerType, samplerParam));

        console.println("ballerina: started publishing traces to Zipkin on " + reporterEndpoint.split("\\?")[0]);
    }

    private static Sampler selectSampler(BString samplerType, BDecimal samplerParam) {
        switch (samplerType.getValue()) {
            default:
            case "const":
                if (samplerParam.value().intValue() == 0) {
                    return Sampler.alwaysOff();
                } else {
                    return Sampler.alwaysOn();
                }
            case "probabilistic":
                return Sampler.traceIdRatioBased(samplerParam.value().doubleValue());
            case RateLimitingSampler.TYPE:
                return new RateLimitingSampler(samplerParam.value().intValue());
        }
    }

    @Override
    public Tracer getTracer(String serviceName) {

        return tracerProviderBuilder.setResource(
                        Resource.create(Attributes.of(SERVICE_NAME, serviceName)))
                .build().get("zipkin");
    }

    @Override
    public ContextPropagators getPropagators() {
        return ContextPropagators.create(B3Propagator.injectingSingleHeader());
    }
}
