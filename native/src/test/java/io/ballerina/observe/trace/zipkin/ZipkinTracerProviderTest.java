/*
 * Copyright (c) 2026, WSO2 LLC. (https://www.wso2.com) All Rights Reserved.
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
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BDecimal;
import io.ballerina.runtime.api.values.BString;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.SpanContext;
import io.opentelemetry.api.trace.TraceFlags;
import io.opentelemetry.api.trace.TraceState;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.context.Context;
import io.opentelemetry.context.propagation.ContextPropagators;
import io.opentelemetry.context.propagation.TextMapGetter;
import io.opentelemetry.context.propagation.TextMapPropagator;
import io.opentelemetry.sdk.trace.samplers.Sampler;
import org.testng.annotations.BeforeMethod;
import org.testng.annotations.Test;

import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.Map;

import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertFalse;
import static org.testng.Assert.assertNotNull;
import static org.testng.Assert.assertTrue;

/**
 * Test class for ZipkinTracerProvider.
 */
public class ZipkinTracerProviderTest {

    private static final String TRACE_ID = "0af7651916cd43dd8448eb211c80319c";
    private static final String SPAN_ID = "b7ad6b7169203331";

    private ZipkinTracerProvider tracerProvider;

    @BeforeMethod
    public void setUp() {
        tracerProvider = new ZipkinTracerProvider();
    }

    @Test
    public void testGetName() {
        assertEquals(tracerProvider.getName(), "zipkin");
    }

    @Test
    public void testInit() {
        // init() does nothing, just ensure it doesn't throw an exception
        tracerProvider.init();
    }

    @Test
    public void testGetPropagatorsInjectsSingleB3Header() {
        ContextPropagators propagators = tracerProvider.getPropagators();
        assertNotNull(propagators);

        SpanContext spanContext = SpanContext.create(TRACE_ID, SPAN_ID, TraceFlags.getSampled(),
                TraceState.getDefault());
        Context context = Context.root().with(Span.wrap(spanContext));
        Map<String, String> carrier = new HashMap<>();
        propagators.getTextMapPropagator().inject(context, carrier, Map::put);

        assertEquals(carrier.size(), 1);
        assertEquals(carrier.get("b3"), TRACE_ID + "-" + SPAN_ID + "-1");
    }

    @Test
    public void testGetPropagatorsExtractsSingleB3Header() {
        TextMapPropagator propagator = tracerProvider.getPropagators().getTextMapPropagator();
        Map<String, String> carrier = new HashMap<>();
        carrier.put("b3", TRACE_ID + "-" + SPAN_ID + "-1");

        Context context = propagator.extract(Context.root(), carrier, new MapGetter());
        SpanContext spanContext = Span.fromContext(context).getSpanContext();

        assertTrue(spanContext.isValid());
        assertTrue(spanContext.isRemote());
        assertTrue(spanContext.isSampled());
        assertEquals(spanContext.getTraceId(), TRACE_ID);
        assertEquals(spanContext.getSpanId(), SPAN_ID);
    }

    @Test
    public void testInitializeConfigurationsAndGetTracer() {
        // alwaysOff sampler (const/0) so no span export is ever attempted -
        // safe to run without a live Zipkin endpoint.
        ZipkinTracerProvider.initializeConfigurations(StringUtils.fromString(""),
                StringUtils.fromString("localhost"), 9411, StringUtils.fromString("const"), BDecimal.valueOf(0),
                1000, 10000);

        Tracer tracer = tracerProvider.getTracer("zipkin-tracer-provider-test");
        assertNotNull(tracer);

        Span span = tracer.spanBuilder("test-span").startSpan();
        assertFalse(span.getSpanContext().isSampled());
        span.end();
    }

    @Test
    public void testInitializeConfigurationsWithReporterEndpoint() {
        ZipkinTracerProvider.initializeConfigurations(StringUtils.fromString("http://localhost:9411/api/v2/spans"),
                StringUtils.fromString("unused-host"), 1, StringUtils.fromString("const"), BDecimal.valueOf(0),
                1000, 10000);

        assertNotNull(tracerProvider.getTracer("zipkin-tracer-provider-test"));
    }

    @Test
    public void testSelectSamplerConstOn() throws ReflectiveOperationException {
        Sampler sampler = invokeSelectSampler("const", BDecimal.valueOf(1));
        assertEquals(sampler.getDescription(), Sampler.alwaysOn().getDescription());
    }

    @Test
    public void testSelectSamplerConstOff() throws ReflectiveOperationException {
        Sampler sampler = invokeSelectSampler("const", BDecimal.valueOf(0));
        assertEquals(sampler.getDescription(), Sampler.alwaysOff().getDescription());
    }

    @Test
    public void testSelectSamplerProbabilistic() throws ReflectiveOperationException {
        Sampler sampler = invokeSelectSampler("probabilistic", BDecimal.valueOf(0.5));
        assertEquals(sampler.getDescription(), Sampler.traceIdRatioBased(0.5).getDescription());
    }

    @Test
    public void testSelectSamplerRateLimiting() throws ReflectiveOperationException {
        Sampler sampler = invokeSelectSampler(RateLimitingSampler.TYPE, BDecimal.valueOf(5));
        assertTrue(sampler instanceof RateLimitingSampler);
    }

    @Test
    public void testSelectSamplerUnknownTypeDefaultsToConst() throws ReflectiveOperationException {
        Sampler sampler = invokeSelectSampler("unrecognized-type", BDecimal.valueOf(1));
        assertEquals(sampler.getDescription(), Sampler.alwaysOn().getDescription());
    }

    private Sampler invokeSelectSampler(String samplerType, BDecimal samplerParam) throws ReflectiveOperationException {
        Method method = ZipkinTracerProvider.class.getDeclaredMethod("selectSampler", BString.class, BDecimal.class);
        method.setAccessible(true);
        return (Sampler) method.invoke(null, StringUtils.fromString(samplerType), samplerParam);
    }

    private static class MapGetter implements TextMapGetter<Map<String, String>> {
        @Override
        public Iterable<String> keys(Map<String, String> carrier) {
            return carrier.keySet();
        }

        @Override
        public String get(Map<String, String> carrier, String key) {
            return carrier == null ? null : carrier.get(key);
        }
    }
}
